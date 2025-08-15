#!/usr/bin/env python3
"""
Legion Setup - Configuration Variable Resolution
Resolves variables and paths in configuration files
"""

import os
import re
from pathlib import Path
from typing import Dict, Any, Union

class ConfigResolver:
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.resolved_cache = {}
    
    def resolve_variables(self, config: Dict[str, Any] = None) -> Dict[str, Any]:
        """Recursively resolve all variables in the configuration."""
        if config is None:
            config = self.config.copy()
        
        # First pass: expand tilde paths
        config = self._expand_tilde_paths(config)
        
        # Second pass: resolve variable references
        config = self._resolve_variable_references(config)
        
        return config
    
    def _expand_tilde_paths(self, obj: Any) -> Any:
        """Expand ~ to home directory in all string values."""
        if isinstance(obj, dict):
            return {key: self._expand_tilde_paths(value) for key, value in obj.items()}
        elif isinstance(obj, list):
            return [self._expand_tilde_paths(item) for item in obj]
        elif isinstance(obj, str):
            if obj.startswith('~'):
                return str(Path(obj).expanduser())
            return obj
        else:
            return obj
    
    def _resolve_variable_references(self, obj: Any, max_iterations: int = 10) -> Any:
        """Resolve ${variable} references in configuration."""
        # Keep resolving until no more variables found or max iterations reached
        for iteration in range(max_iterations):
            resolved_obj = self._resolve_variables_single_pass(obj)
            if self._has_unresolved_variables(resolved_obj):
                obj = resolved_obj
                continue
            else:
                return resolved_obj
        
        # If we reach here, there might be circular references
        print(f"Warning: Could not resolve all variables after {max_iterations} iterations")
        return resolved_obj
    
    def _resolve_variables_single_pass(self, obj: Any) -> Any:
        """Single pass of variable resolution."""
        if isinstance(obj, dict):
            return {key: self._resolve_variables_single_pass(value) for key, value in obj.items()}
        elif isinstance(obj, list):
            return [self._resolve_variables_single_pass(item) for item in obj]
        elif isinstance(obj, str):
            return self._resolve_string_variables(obj)
        else:
            return obj
    
    def _resolve_string_variables(self, text: str) -> str:
        """Resolve ${variable.path} references in a string."""
        # Pattern to match ${variable.path} or ${variable}
        pattern = r'\$\{([^}]+)\}'
        
        def replace_var(match):
            var_path = match.group(1)
            try:
                value = self._get_nested_value(self.config, var_path)
                return str(value) if value is not None else match.group(0)
            except (KeyError, TypeError):
                # Variable not found, leave as is
                return match.group(0)
        
        return re.sub(pattern, replace_var, text)
    
    def _get_nested_value(self, config: Dict[str, Any], path: str) -> Any:
        """Get a nested value from config using dot notation (e.g., 'base_paths.workspace_root')."""
        keys = path.split('.')
        current = config
        
        for key in keys:
            if isinstance(current, dict) and key in current:
                current = current[key]
            else:
                raise KeyError(f"Path '{path}' not found in configuration")
        
        return current
    
    def _has_unresolved_variables(self, obj: Any) -> bool:
        """Check if there are still unresolved ${} variables."""
        if isinstance(obj, dict):
            return any(self._has_unresolved_variables(value) for value in obj.values())
        elif isinstance(obj, list):
            return any(self._has_unresolved_variables(item) for item in obj)
        elif isinstance(obj, str):
            return '${' in obj
        else:
            return False
    
    def get_resolved_path(self, path_key: str) -> Path:
        """Get a resolved path as a Path object."""
        resolved_config = self.resolve_variables()
        
        # Handle nested path keys like 'paths.enterprise_repo_path'
        try:
            path_str = self._get_nested_value(resolved_config, path_key)
            return Path(path_str).expanduser().resolve()
        except KeyError:
            raise ValueError(f"Path key '{path_key}' not found in configuration")
    
    def ensure_directory_exists(self, path_key: str) -> Path:
        """Ensure a directory exists and return the Path object."""
        path = self.get_resolved_path(path_key)
        path.mkdir(parents=True, exist_ok=True)
        return path
    
    def get_workspace_structure(self) -> Dict[str, Path]:
        """Get all workspace paths as resolved Path objects."""
        resolved_config = self.resolve_variables()
        
        base_paths = resolved_config.get('base_paths', {})
        paths = resolved_config.get('paths', {})
        repositories = resolved_config.get('repositories', {})
        
        structure = {}
        
        # Add base paths
        if 'workspace_root' in base_paths:
            structure['workspace_root'] = Path(base_paths['workspace_root']).expanduser().resolve()
            structure['code_directory'] = structure['workspace_root'] / base_paths.get('code_directory', 'code')
        
        # Add repository paths
        for repo_name, repo_config in repositories.items():
            if 'path' in repo_config:
                structure[f'{repo_name}_repo'] = Path(repo_config['path']).expanduser().resolve()
        
        # Add other paths
        for path_name, path_value in paths.items():
            if path_value and not path_name.endswith('_install_path'):
                structure[path_name] = Path(path_value).expanduser().resolve()
        
        return structure
    
    def create_workspace_structure(self) -> Dict[str, Path]:
        """Create the entire workspace directory structure."""
        structure = self.get_workspace_structure()
        
        print("📁 Setting up workspace directories:")
        
        # Create directories in logical order
        directories_to_create = [
            ('workspace_root', 'Workspace root directory'),
            ('code_directory', 'Source code directory'),
        ]
        
        # Add repository parent directories (but not the repos themselves - git will create those)
        for name, path in structure.items():
            if name.endswith('_repo_path') or name.endswith('_repo'):
                parent_name = f"{name}_parent"
                parent_path = path.parent
                directories_to_create.append((parent_name, f"Parent for {name}", parent_path))
        
        created_dirs = []
        for item in directories_to_create:
            if len(item) == 3:
                name, description, path = item
            else:
                name, description = item
                path = structure.get(name)
            
            if path and not path.exists():
                try:
                    path.mkdir(parents=True, exist_ok=True)
                    created_dirs.append(path)
                    print(f"  ✅ {description}: {path}")
                except PermissionError:
                    print(f"  ❌ Permission denied: {path}")
                    raise
                except Exception as e:
                    print(f"  ❌ Failed to create {path}: {e}")
                    raise
            elif path and path.exists():
                print(f"  ✅ {description}: {path} (already exists)")
        
        if created_dirs:
            print(f"\n🎉 Created {len(created_dirs)} new directories")
        else:
            print("\n✅ All workspace directories already exist")
        
        return structure
    
    def validate_workspace_permissions(self) -> bool:
        """Validate that we have write permissions in the workspace."""
        structure = self.get_workspace_structure()
        
        workspace_root = structure.get('workspace_root')
        if not workspace_root:
            return True
        
        # Check if we can write to the workspace root
        try:
            test_file = workspace_root / '.legion_write_test'
            test_file.touch()
            test_file.unlink()
            return True
        except (PermissionError, OSError):
            print(f"❌ No write permissions in workspace: {workspace_root}")
            return False

# Example usage and testing
if __name__ == "__main__":
    # Test configuration
    test_config = {
        "base_paths": {
            "workspace_root": "~/Development/legion",
            "code_directory": "code"
        },
        "paths": {
            "enterprise_repo_path": "${base_paths.workspace_root}/${base_paths.code_directory}/enterprise",
            "console_ui_repo_path": "${base_paths.workspace_root}/${base_paths.code_directory}/console-ui"
        },
        "repositories": {
            "enterprise": {
                "url": "git@github.com:legionco/enterprise.git",
                "path": "${base_paths.workspace_root}/${base_paths.code_directory}/enterprise"
            }
        }
    }
    
    resolver = ConfigResolver(test_config)
    resolved = resolver.resolve_variables()
    
    print("Resolved configuration:")
    import json
    print(json.dumps(resolved, indent=2))
    
    print("\nWorkspace structure:")
    structure = resolver.get_workspace_structure()
    for name, path in structure.items():
        print(f"{name}: {path}")
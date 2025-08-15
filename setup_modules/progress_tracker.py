#!/usr/bin/env python3
"""
Legion Setup - Progress Tracking Module
Tracks setup progress and enables resumable installation
"""

import os
import json
import time
import hashlib
import uuid
from pathlib import Path
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, asdict
from datetime import datetime

@dataclass
class StageStatus:
    name: str
    status: str  # pending, in_progress, completed, failed
    stage_id: str  # unique identifier for this stage
    checksum: Optional[str] = None  # config checksum to detect changes
    start_time: Optional[float] = None
    end_time: Optional[float] = None
    error_message: Optional[str] = None
    details: Dict[str, Any] = None

    def __post_init__(self):
        if self.details is None:
            self.details = {}

class ProgressTracker:
    def __init__(self, setup_dir: Path, config_data: Dict = None):
        self.setup_dir = setup_dir
        self.metadata_file = setup_dir / "setup_progress.json"
        self.config_data = config_data or {}
        self.session_id = str(uuid.uuid4())[:8]  # unique session identifier
        
        # Define stages with unique IDs and descriptions
        self.stage_definitions = {
            "validation": {
                "id": "VAL-001",
                "description": "Environment validation and prerequisite checks",
                "dependencies": []
            },
            "prerequisites": {
                "id": "PRE-002", 
                "description": "System prerequisites verification",
                "dependencies": ["validation"]
            },
            "homebrew_install": {
                "id": "HBR-003",
                "description": "Homebrew package manager installation",
                "dependencies": ["prerequisites"]
            },
            "java_install": {
                "id": "JDK-004",
                "description": "Java JDK 17 installation and setup",
                "dependencies": ["homebrew_install"]
            },
            "maven_install": {
                "id": "MVN-005",
                "description": "Apache Maven build tool installation",
                "dependencies": ["java_install"]
            },
            "node_install": {
                "id": "NOD-006",
                "description": "Node.js and npm installation",
                "dependencies": ["homebrew_install"]
            },
            "mysql_install": {
                "id": "SQL-007",
                "description": "MySQL database server installation",
                "dependencies": ["homebrew_install"]
            },
            "docker_setup": {
                "id": "DOC-008",
                "description": "Docker Desktop installation and configuration",
                "dependencies": ["prerequisites"]
            },
            "git_github_setup": {
                "id": "GIT-009",
                "description": "Git configuration and GitHub SSH setup",
                "dependencies": ["prerequisites"]
            },
            "jfrog_maven_setup": {
                "id": "JFR-010",
                "description": "JFrog Artifactory Maven settings configuration",
                "dependencies": ["maven_install"]
            },
            "database_setup": {
                "id": "DBS-011",
                "description": "MySQL database creation and data import",
                "dependencies": ["mysql_install"]
            },
            "repository_clone": {
                "id": "REP-012",
                "description": "Clone Legion repositories (enterprise + console-ui)",
                "dependencies": ["git_github_setup"]
            },
            "intellij_setup": {
                "id": "IDE-013",
                "description": "IntelliJ IDEA configuration and project setup",
                "dependencies": ["repository_clone", "maven_install"]
            },
            "build_verification": {
                "id": "BLD-014",
                "description": "Maven build and compilation verification",
                "dependencies": ["jfrog_maven_setup", "database_setup"]
            },
            "final_validation": {
                "id": "FIN-015",
                "description": "Final environment validation and health checks",
                "dependencies": ["build_verification", "intellij_setup"]
            }
        }
        
        self.stages = list(self.stage_definitions.keys())
        self.progress_data = self._load_progress()

    def _load_progress(self) -> Dict[str, StageStatus]:
        """Load existing progress from metadata file."""
        if not self.metadata_file.exists():
            return self._initialize_progress()
        
        try:
            with open(self.metadata_file, 'r') as f:
                data = json.load(f)
            
            # Convert dict back to StageStatus objects
            progress = {}
            for stage_name, stage_data in data.get('stages', {}).items():
                progress[stage_name] = StageStatus(**stage_data)
            
            return progress
        except (json.JSONError, KeyError, TypeError) as e:
            print(f"Warning: Could not load progress file, starting fresh: {e}")
            return self._initialize_progress()

    def _initialize_progress(self) -> Dict[str, StageStatus]:
        """Initialize progress with all stages as pending."""
        config_checksum = self._calculate_config_checksum()
        return {
            stage_name: StageStatus(
                name=stage_name,
                stage_id=self.stage_definitions[stage_name]["id"],
                status="pending",
                checksum=config_checksum
            )
            for stage_name in self.stages
        }
    
    def _calculate_config_checksum(self) -> str:
        """Calculate checksum of relevant configuration to detect changes."""
        # Create a deterministic string from key config values
        config_str = json.dumps({
            "versions": self.config_data.get("versions", {}),
            "paths": self.config_data.get("paths", {}),
            "setup_options": self.config_data.get("setup_options", {}),
            "user": self.config_data.get("user", {})
        }, sort_keys=True)
        
        return hashlib.md5(config_str.encode()).hexdigest()[:12]

    def _save_progress(self):
        """Save current progress to metadata file."""
        try:
            # Convert StageStatus objects to dict for JSON serialization
            stages_data = {
                stage_name: asdict(stage_status)
                for stage_name, stage_status in self.progress_data.items()
            }
            
            metadata = {
                "last_updated": time.time(),
                "setup_version": "1.0.0",
                "session_id": self.session_id,
                "config_checksum": self._calculate_config_checksum(),
                "total_stages": len(self.stages),
                "completed_stages": len([s for s in self.progress_data.values() if s.status == "completed"]),
                "stage_definitions": self.stage_definitions,
                "stages": stages_data
            }
            
            with open(self.metadata_file, 'w') as f:
                json.dump(metadata, f, indent=2)
        except Exception as e:
            print(f"Warning: Could not save progress: {e}")

    def start_stage(self, stage_name: str) -> bool:
        """Mark a stage as started."""
        if stage_name not in self.progress_data:
            print(f"Warning: Unknown stage '{stage_name}'")
            return False
        
        self.progress_data[stage_name].status = "in_progress"
        self.progress_data[stage_name].start_time = time.time()
        self._save_progress()
        return True

    def complete_stage(self, stage_name: str, details: Optional[Dict[str, Any]] = None) -> bool:
        """Mark a stage as completed."""
        if stage_name not in self.progress_data:
            print(f"Warning: Unknown stage '{stage_name}'")
            return False
        
        stage = self.progress_data[stage_name]
        stage.status = "completed"
        stage.end_time = time.time()
        if details:
            stage.details.update(details)
        
        self._save_progress()
        return True

    def fail_stage(self, stage_name: str, error_message: str, details: Optional[Dict[str, Any]] = None) -> bool:
        """Mark a stage as failed."""
        if stage_name not in self.progress_data:
            print(f"Warning: Unknown stage '{stage_name}'")
            return False
        
        stage = self.progress_data[stage_name]
        stage.status = "failed"
        stage.end_time = time.time()
        stage.error_message = error_message
        if details:
            stage.details.update(details)
        
        self._save_progress()
        return True

    def get_stage_status(self, stage_name: str) -> Optional[StageStatus]:
        """Get status of a specific stage."""
        return self.progress_data.get(stage_name)

    def is_stage_completed(self, stage_name: str) -> bool:
        """Check if a stage is completed."""
        stage = self.progress_data.get(stage_name)
        return stage is not None and stage.status == "completed"

    def get_next_pending_stage(self) -> Optional[str]:
        """Get the next stage that needs to be executed."""
        for stage_name in self.stages:
            stage = self.progress_data[stage_name]
            if stage.status in ["pending", "failed"]:
                return stage_name
        return None

    def get_resume_point(self) -> Optional[str]:
        """Get the stage from which setup should resume."""
        # Look for first non-completed stage
        for stage_name in self.stages:
            stage = self.progress_data[stage_name]
            if stage.status != "completed":
                return stage_name
        return None

    def reset_from_stage(self, stage_name: str):
        """Reset all stages from the given stage onwards."""
        found_stage = False
        for current_stage in self.stages:
            if current_stage == stage_name:
                found_stage = True
            
            if found_stage:
                stage = self.progress_data[current_stage]
                stage.status = "pending"
                stage.start_time = None
                stage.end_time = None
                stage.error_message = None
                stage.details = {}
        
        self._save_progress()

    def get_progress_summary(self) -> Dict[str, Any]:
        """Get a summary of the current progress."""
        completed = [s for s in self.progress_data.values() if s.status == "completed"]
        failed = [s for s in self.progress_data.values() if s.status == "failed"]
        in_progress = [s for s in self.progress_data.values() if s.status == "in_progress"]
        
        total_time = 0
        for stage in completed:
            if stage.start_time and stage.end_time:
                total_time += stage.end_time - stage.start_time

        return {
            "total_stages": len(self.stages),
            "completed": len(completed),
            "failed": len(failed),
            "in_progress": len(in_progress),
            "pending": len(self.stages) - len(completed) - len(failed) - len(in_progress),
            "completion_percentage": (len(completed) / len(self.stages)) * 100,
            "total_time_spent": total_time,
            "failed_stages": [s.name for s in failed],
            "next_stage": self.get_next_pending_stage()
        }

    def print_progress_report(self):
        """Print a detailed progress report."""
        summary = self.get_progress_summary()
        
        print("\n" + "="*60)
        print("LEGION SETUP PROGRESS REPORT")
        print("="*60)
        print(f"Completion: {summary['completion_percentage']:.1f}% ({summary['completed']}/{summary['total_stages']} stages)")
        
        if summary['total_time_spent'] > 0:
            minutes = summary['total_time_spent'] / 60
            print(f"Time spent: {minutes:.1f} minutes")
        
        if summary['failed'] > 0:
            print(f"❌ Failed stages: {', '.join(summary['failed_stages'])}")
        
        if summary['next_stage']:
            print(f"🔄 Next stage: {summary['next_stage']}")
        
        print("\nStage Details:")
        print("-" * 40)
        
        for stage_name in self.stages:
            stage = self.progress_data[stage_name]
            stage_def = self.stage_definitions[stage_name]
            icon = {
                "completed": "✅",
                "in_progress": "🔄", 
                "failed": "❌",
                "pending": "⏳"
            }.get(stage.status, "❓")
            
            duration = ""
            if stage.start_time and stage.end_time:
                duration = f" ({(stage.end_time - stage.start_time):.1f}s)"
            
            print(f"{icon} [{stage.stage_id}] {stage_def['description']}{duration}")
            
            if stage.error_message:
                print(f"   Error: {stage.error_message}")
            
            # Show dependencies if stage is pending/failed
            if stage.status in ["pending", "failed"] and stage_def["dependencies"]:
                deps = [self.stage_definitions[dep]["id"] for dep in stage_def["dependencies"]]
                print(f"   Depends on: {', '.join(deps)}")
        
        print("="*60)

    def cleanup_metadata(self):
        """Remove the progress metadata file."""
        if self.metadata_file.exists():
            self.metadata_file.unlink()

    def should_skip_stage(self, stage_name: str, force_reinstall: bool = False) -> bool:
        """Determine if a stage should be skipped based on current status."""
        if force_reinstall:
            return False
        
        return self.is_stage_completed(stage_name)
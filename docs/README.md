# Legion Development Documentation

Welcome to the Legion development documentation. This directory contains comprehensive guides, analyses, and reference materials for the Legion development environment.

## 📚 Documentation Index

### Performance & Optimization
- **[Backend Startup Performance Analysis](backend-startup-performance-analysis.md)**  
  Comprehensive analysis of why the backend takes 20-30 minutes to start and how to fix it

- **[Startup Optimization Quick Reference](startup-optimization-quick-reference.md)**  
  Quick guide with immediate actions to speed up backend startup

### Issue Analysis & Solutions
- **[Backend Issues Analysis](BACKEND_ISSUES_ANALYSIS.md)**  
  Analysis of common backend runtime issues and their solutions

- **[Flyway Migration Skip Guide](FLYWAY_SKIP.md)**  
  How to skip Flyway migrations for faster development

### Development History
- **[Changes Summary](CHANGES_SUMMARY.md)**  
  Summary of all changes made to the development environment

## 🔧 Fix Scripts Documentation

The `scripts/` directory contains automated fix scripts for common issues:

### Database Fixes
- **`fix-mysql-collation.sh`** - Fixes "Illegal mix of collations" errors
- **`fix-dynamicgroup-workrole-db.sh`** - Fixes Dynamic Group enum deserialization

### Configuration Fixes  
- **`fix-connection-pool-config.sh`** - Optimizes database connection pools
- **`fix-cache-timeout-config.sh`** - Fixes cache timeout issues
- **`fix-cache-tolerance.sh`** - Adjusts cache validation tolerances

## 📊 Key Performance Metrics

| Component | Current Time | Optimized Time | Documentation |
|-----------|--------------|----------------|---------------|
| Backend Startup | 20-30 min | 8-12 min | [Performance Analysis](backend-startup-performance-analysis.md) |
| Repository Scanning | 87 sec | 20 sec | [Quick Reference](startup-optimization-quick-reference.md) |
| JPA Initialization | 5 min | 1 min | [Performance Analysis](backend-startup-performance-analysis.md#jpa-initialization) |
| Flyway Validation | 5 sec | 2 sec | [Flyway Skip](FLYWAY_SKIP.md) |

## 🚀 Quick Start Optimization

For immediate improvements, add these to your `local.values.yml`:

```yaml
spring_main_lazy_initialization: true
spring_jpa_open_in_view: false
cache_bootstrap_timeout: 60
scheduled_task_cache_timeout: 60
datasource_max_active: 300
```

See [Startup Optimization Quick Reference](startup-optimization-quick-reference.md) for full details.

## 📈 Version History

### v14 (Current)
- Runtime fixes and performance optimizations
- Connection pool improvements (300 connections)
- Cache timeout fixes (60 minute bootstrap)
- MySQL collation standardization
- Dynamic Group WorkRole fix

### Previous Versions
- v13: Cache bootstrap timeout increase
- v12: Backend runtime fixes
- v11: LocalStack integration
- v10: MySQL setup improvements

## 🆘 Troubleshooting

### Common Issues

1. **Slow Startup** → See [Performance Analysis](backend-startup-performance-analysis.md)
2. **Connection Pool Exhaustion** → Run `scripts/fix-connection-pool-config.sh`
3. **Cache Timeouts** → Run `scripts/fix-cache-timeout-config.sh`
4. **Collation Errors** → Run `scripts/fix-mysql-collation.sh`
5. **Dynamic Group Errors** → Run `scripts/fix-dynamicgroup-workrole-db.sh`

## 📝 Contributing

When adding new documentation:
1. Place it in this `docs/` directory
2. Update this README with a link and description
3. Use clear, descriptive filenames
4. Include a header with purpose, version, and date
5. Add to the appropriate section above

## 📞 Support

- **Slack**: `#devops-it-support`
- **GitHub Issues**: [legion-dev-oneclick-setup/issues](https://github.com/kumar-ramaiyer/legion-dev-oneclick-setup/issues)
- **Wiki**: [Legion Development Wiki](https://legiontech.atlassian.net/wiki)

---

*Last Updated: December 2024*  
*Maintained by: Legion DevOps Team*
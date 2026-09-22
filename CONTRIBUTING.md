# Contributing

1. Create a short-lived branch from `main`.
2. Add or update tests with each behavioural change.
3. Run `devtools::document()`, `devtools::test()` and `devtools::check()`.
4. Update `NEWS.md` for user-visible changes.
5. Open a pull request that states the problem, method, evidence and operational limitations.
6. Do not commit downloaded NetCDF files, outputs, credentials or `.RData` files.

All R source files must retain the mandatory Flode header. Public functions require roxygen2 documentation and examples. Use snake_case verbs, descriptive nouns and `_dt` suffixes for data.table objects.

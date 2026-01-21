# Migration Plan

## Status
The repository restructuring was attempted but encountered environment limitations preventing file moves.
The following artifacts have been created to guide the manual restructuring:

1.  `Docs/RepoShape.md`: Defines the target structure.
2.  `Docs/ThirdParty.md`: Defines the third-party dependency policy.
3.  `Docs/setup_repo.py`: A Python script to automate the directory creation and file moves.
4.  `Docs/Package.swift.template`: A template for the new Package.swift.
5.  `Docs/App.swift.template`: A template for the cleaned App entry point.

## Manual Steps
To complete the restructuring, run the following command from the repository root:

```bash
python3 Docs/setup_repo.py
```

Then, verify the build using:

```bash
swift build
# or
xcodebuild -project App/Anigma.xcodeproj -scheme Anigma
```

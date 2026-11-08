# Security

## Runtime boundary

This project is a local desktop game. The implemented game flow uses local scenes and resources, with session progress held in memory. It has no player accounts, server endpoints, or runtime secret configuration.

## Repository and releases

Use trusted Godot binaries and export templates. Review third-party scripts and editor plugins before running them. Keep local caches, test captures, and credentials out of release artifacts. Check distribution rights for reference artwork, music, and other third-party assets before publishing a build.

## Local development records

`.archive/` is excluded from Git and Godot scanning. Keep local research and development records there; required test fixtures remain committed separately. Ignore rules do not provide access control or erase files from earlier Git history. Store secrets outside project notes and review the files included in a release.

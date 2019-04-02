## Bonsai CI helper scripts for ruby-runtime based assets

This directory contains helper scripts that can be used to automate Bonsai asset build as part of Sensu ruby plugin release process.

### TravisCI Example Usage

Make sure secure `GITHUB_TOKEN` is set travis environment.

Clone into bonsai directory `before_deploy`
```
before_deploy:
  - git clone https://github.com/sensu/sensu-go-bonsai-asset.git --branch feature/ruby-plugin-assets bonsai
```

Create a deploy provider to run the travis build script
```
  - provider: script
    script: bonsai/ruby-runtime/travis-build-bonsai-assets.sh sensu-plugins-disk-checks
    skip_cleanup: true
    on:
      tags: true
      all_branches: true
      rvm: 2.4.1

```

#### Build script will:

* builds bonsai assets tarballs
* generate sha512 checksum file
* upload bonsai assets into tagged github release


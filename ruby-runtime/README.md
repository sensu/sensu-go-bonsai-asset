## Bonsai CI helper scripts for ruby-runtime based assets

This directory contains helper scripts that can be used to automate Bonsai asset build as part of Sensu ruby plugin release process.

### Bonsai 
The provided Bonsai example configuration file `.bonsai.yml.example` defines Sensu assets for each of the supported ruby-runtime platforms.

### TravisCI Example Usage

Make sure secure `GITHUB_TOKEN` is set in the Travis environment using a valid Github personal access token.

Clone into bonsai directory use TravisCI `before_deploy` hook:
```
before_deploy:
  - bash -c "[ ! -d bonsai/ ] && git clone https://github.com/sensu/sensu-go-bonsai-asset.git bonsai || echo 'bonsai/ exists, skipping git clone'"
```

Create a deploy provider to run the travis build script
```
  - provider: script
    script: bonsai/ruby-runtime/travis-build-ruby-plugin-assets.sh sensu-plugins-disk-checks
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


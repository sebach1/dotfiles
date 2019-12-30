# dotfiles
> Disclaimer: the project isn't serious. It contains experiments with git hists and weird things. Use it at your own risk.

**Table of Contents**

<!-- toc -->

- [About](#about)
  * [Installing](#installing)
  * [Customizing](#customizing)
- [Resources](#resources)
  * [`.vim`](#vim)
- [Contributing](#contributing)
  * [Running the tests](#running-the-tests)

<!-- tocstop -->

## About

### Installing

```console
$ make
```

This will create symlinks from this repo to your home folder.

### Customizing

Mod env vars, etc in the `./.extra` file.

## Resources

### `.vim`

For my `.vimrc` and `.vim` dotfiles see
[github.com/sebach1/.vim](https://github.com/sebach1/.vim).

### Running the tests

The tests use [shellcheck](https://github.com/koalaman/shellcheck). You don't
need to install anything. They run in a container.

```console
$ make test
```

## CMD

Explanation:
 - genuinetools: taken from github.com/genuinetools
 - #: declared in ./bin
 - *: declared in ./.functions
 - +: declared in ./.dockerfunc

### Bash

 - speedtest
 - weather (genuinetools)
 - udict (genuinetools)
 - tdash
 - afk
 - screen-backlight (#)
 - slackpm (#)
 - update-firmware (#)
 - mkd (*)
 - calc (*)
 - tmpd (*)
 - fsz (*)
 - dataurl (*)
 - gitio (*)
 - server (*)
 - json (*)
 - mwiki (*)
 - escape (*)
 - openimg*)
 - gogo (*)
 - golistdeps (*)
 - govendorcheck (*)


### Git

 - check-go-repos (#)
 - pepper
 - icdiff

### Go IDE

 - goimports
 - gorename
 - golint
 - guru
 - gopls
 - cover
 - staticcheck
 - golangci-lint
 - gotags
 - gocode
 - godef

### Infra

- getcertnames(*)
- amicontained
- certok (genuinetools)
- reg (genuinetools)
- browser-exec (#) 
- cleanup-non-running-images (#) 
- del_stopped (+)
- rmctr (+)
- relies_on (+)

### Other

- hmrandr (*)
- ofirandr (*)
- gmailfilters
- sembump
- htotheizzg

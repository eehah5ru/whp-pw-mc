# WHPH MAster of Ceremony

gui for editing/testing whph website content locally using vagrant to absctract from os

## install requirements
- download MC app. link to releases: TBA
- install Virtual Box
- change VM folder to external drive if needed
- install vagrant
- install latest JDK -> copy to /Library/Java/JavaVirtualMachines
- update JDK Home -> cd /Library/Java/JavaVirtualMachines; ln -s /Library/Java/JavaVirtualMachines/jdk-13.0.1.jdk/Contents/Home


## dev requirements

install shoes4 using git. for details: https://github.com/shoes/shoes4

change `ruby-version` to latest `jruby`

add `fastimage` to shoes's `Gemfile`. It's needed to package.

We don't use project Gemfile because in this case the app building process is broken

- rvm
- jruby
- `gem install shoes -v 4.0.0.rc1`
- `gem install fastimage`

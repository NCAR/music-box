#!/bin/bash

this_dir=$(pwd)
printf "\nSubmodule status\n"
printf "(currently checked out commit for each submodule)\n"
printf "(when the submodule is initialized and a tag exists, the commit is shown as: 'most recent tag-commits since tag-commit hash')\n"
printf "(when the submodule is not initialized, only the checked out commit is shown)\n\n"
grep path .gitmodules | sed 's/.*= //' | while read x
do
  cd "$this_dir"
  printf "$x\n   - current commit: "
  if [ "$(ls -A $x)" ] ; then
    cd "$x"
    git describe --tags --always
  else
    git submodule status $x | sed 's/^-//' | awk '{ print $1 }'
  fi
done
printf "\n"

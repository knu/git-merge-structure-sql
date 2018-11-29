# git-merge-structure-sql

This is a merge driver for Git that resolves trivial parts of
merge conflicts in a db/structure.sql file of Rails.

Currently only PostgreSQL and MySQL dump formats are supported.

## Installation

Run this:

    $ gem install git-merge-structure-sql

And enable it yourself in your Git configuration, or let it do that
for you by this command:

    $ git-merge-structure-sql --install

This adds necessary settings to your
`~/.gitconfig`/`$XDG_CONFIG_HOME/git/config` and the default
gitattributes(5) file to enable the merge driver for structure.sql
files.

## Usage

Once enabled, Git should call this driver as necessary when it needs
to merge changes made in structure.sql.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/knu/git-merge-structure-sql.

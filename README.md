# git-merge-structure-sql

This is a merge driver for Git that resolves typical merge conflicts
in a `db/structure.sql` file of Rails.

When your project is configured with
`config.active_record.schema_format = :sql`, the database schema is
kept in `db/structure.sql` instead of `db/schema.rb` in the native
dump format of the underlying database engine, which is not suitable
for the default merge driver of Git to deal with.  As a result, when
you try to merge two branches you always have to resolve trivial
conflicts manually if new schema migrations take place in both
branches.  This custom driver takes away such a pain.

Currently only PostgreSQL, MySQL and SQLite3 dump formats are
supported.

## Installation

Run this:

    $ gem install git-merge-structure-sql

And enable it yourself in your Git configuration, or let it do that
for you by this command:

    $ git-merge-structure-sql --install

This adds necessary settings to your `~/.gitconfig` or
`$XDG_CONFIG_HOME/git/config` and the default gitattributes(5) file to
enable the merge driver for structure.sql files.

If you want to enable this driver only in the current git directory,
run this:

    $ git-merge-structure-sql --install=local

## Usage

Once enabled, Git should call this driver as necessary when it needs
to merge changes made in structure.sql.

## History

See `CHANGELOG.md` for the version history.

## Author

Copyright (c) 2018-2021 Akinori MUSHA.

Licensed under the 2-clause BSD license.  See `LICENSE.txt` for
details.

Visit the [GitHub Repository](https://github.com/knu/sidetiq-timezone)
for the latest information.

use SQLite3;

class Squerl::Dataset {
    has $.db;
    has %.opts;

    multi method new($db, *%opts) {
        self.bless(self.CREATE(), :$db, :%opts);
    }

    multi method clone(*%opts) {
        my %new-opts = %!opts, %opts;
        self.bless(self.CREATE(), :db($!db), :opts(%new-opts));
    }

    method insert(*@values) {
        my $values = @values>>.perl.join(', ');
        given $!db {
            .open;
            # RAKUDO: Real string interpolation
            .exec("INSERT INTO {%!opts<table>} VALUES($values)");
            .close;
        }
    }

    method all() {
        $!db.select("*", %!opts<table>);
    }
}

class Squerl::Database {
    has $!file;
    has $!dbh;

    submethod BUILD(:$file!) {
        $!file = $file; # RAKUDO: This shouldn't be needed
    }

    method open() {
        $!dbh = sqlite_open($!file);
    }

    method close() {
        $!dbh.close();
    }

    method exec($statement) {
        my $sth = $!dbh.prepare($statement);
        $sth.step();
        $sth.finalize();
    }

    method create_table($_: *@args) {
        my $table-name = @args[0];
        my $columns = join ', ', gather for @args[1..^*] -> $type, $name {
            given $type.lc {
                when 'primary_key'   { take "$name INTEGER PRIMARY KEY ASC" }
                when 'int'|'integer' { take "$name INTEGER" }
                when 'str'|'string'  { take "$name TEXT" }
                default              { die "Unknown type $type" }
            }
        };
        .open;
        .exec("CREATE TABLE $table-name ($columns)");
        .close;
    }

    method select($_: $what, $table) {
        my @rows;
        .open;
        my $sth = $!dbh.prepare("SELECT $what FROM $table");
        while $sth.step() == 100 {
            push @rows, [map { $sth.column_text($_) }, ^$sth.column_count()];
        }
        .close;
        return @rows;
    }

    method from($table) {
        return Squerl::Dataset.new(self, :$table);
    }
}

class Squerl {
    method sqlite($file) {
        return Squerl::Database.new(:$file);
    }
}

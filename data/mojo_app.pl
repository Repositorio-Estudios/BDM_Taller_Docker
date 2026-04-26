use Mojolicious::Lite;
use DBI;
use MongoDB;
use JSON;
use File::Slurp;
use Data::Dumper;
use Mojo::JSON qw(decode_json);
use Mojo::UserAgent;

my $SQLITE_PATH = '/app/data/almacen.sqlite';

# Conectar a SQLite
sub get_sqlite {
    my $dbh = DBI->connect(
        "dbi:SQLite:dbname=$SQLITE_PATH", '', '',
        { RaiseError => 1, AutoCommit => 1 }
    );
    $dbh->do('PRAGMA foreign_keys = ON');
    return $dbh;
}

# Función para registrar mensajes de depuración
sub log_debug {
    my ($message) = @_;
    my $log_file = '/app/data/debug.log';  # Especifica la ruta completa al archivo de log
    open my $fh, '>>', $log_file or die "No se puede abrir el archivo: $!";
    print $fh localtime() . " - $message\n";  # Incluye timestamp
    close $fh;
}

# Función para cargar datos desde archivos JSON a MongoDB
sub load_data_to_mongo {

}

# Elimina dígitos no numéricos de un valor; retorna undef si queda vacío
sub limpiar_valor_numerico {
    my ($valor) = @_;
    return undef unless defined $valor;
    (my $solo = "$valor") =~ s/[^0-9]//g;
    return length($solo) ? int($solo) : undef;
}

# Función para extraer y cargar artículos
sub etl_process_articulos {
    my $dbh    = get_sqlite();
    my $client = MongoDB::MongoClient->new(host => 'mongodb://mongodb_articulos:27017');
    my $col    = $client->get_database('almacen')->get_collection('articulos');
    my @docs   = $col->find()->all();

    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS articulos (
            idArticulo       INTEGER PRIMARY KEY,
            nombreArticulo   TEXT    NOT NULL,
            precioArticulo   REAL    NOT NULL,
            cantidadArticulo INTEGER NOT NULL
        )
    });
    $dbh->do('DELETE FROM articulos');

    my $sth = $dbh->prepare('INSERT OR REPLACE INTO articulos VALUES (?,?,?,?)');
    my ($ok, $skip) = (0, 0);
    $dbh->begin_work;
    for my $doc (@docs) {
        my $id_art   = limpiar_valor_numerico($doc->{idArticulo});
        my $cantidad = limpiar_valor_numerico($doc->{cantidadArticulo});
        unless (defined $id_art && defined $cantidad) { $skip++; next }
        $sth->execute(
            $id_art,
            $doc->{nombreArticulo} // '',
            $doc->{precioArticulo} + 0,
            $cantidad
        );
        $ok++;
    }
    $dbh->commit;
    log_debug("ETL articulos: $ok insertados, $skip descartados");
    return ($ok, $skip);
}


# Función para extraer y cargar personas
sub etl_process_personas {
    my $dbh    = get_sqlite();
    my $client = MongoDB::MongoClient->new(host => 'mongodb://mongodb_personas:27017');
    my $col    = $client->get_database('almacen')->get_collection('personas');
    my @docs   = $col->find()->all();

    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS personas (
            numeroDocumento  INTEGER PRIMARY KEY,
            nombres          TEXT NOT NULL,
            primerApellido   TEXT NOT NULL,
            segundoApellido  TEXT,
            fechaNacimiento  TEXT,
            telefono         INTEGER,
            direccion        TEXT,
            email            TEXT
        )
    });
    $dbh->do('DELETE FROM personas');

    my $sth = $dbh->prepare('INSERT OR REPLACE INTO personas VALUES (?,?,?,?,?,?,?,?)');
    my ($ok, $skip) = (0, 0);
    $dbh->begin_work;
    for my $doc (@docs) {
        my $num_doc  = limpiar_valor_numerico($doc->{numeroDocumento});
        my $telefono = limpiar_valor_numerico($doc->{telefono});
        unless (defined $num_doc && defined $telefono) { $skip++; next }
        $sth->execute(
            $num_doc,
            $doc->{nombres}         // '',
            $doc->{primerApellido}  // '',
            $doc->{segundoApellido} // '',
            $doc->{fechaNacimiento} // '',
            $telefono,
            $doc->{direccion} // '',
            $doc->{email}     // ''
        );
        $ok++;
    }
    $dbh->commit;
    log_debug("ETL personas: $ok insertadas, $skip descartadas");
    return ($ok, $skip);
}

# Función para extraer y cargar ventas
sub etl_process_ventas {
    my $dbh    = get_sqlite();
    my $client = MongoDB::MongoClient->new(host => 'mongodb://mongodb_ventas:27017');
    my $col    = $client->get_database('almacen')->get_collection('ventas');
    my @docs   = $col->find()->all();

    my %ids_personas  = map { $_->[0] => 1 }
        @{ $dbh->selectall_arrayref('SELECT numeroDocumento FROM personas') };
    my %ids_articulos = map { $_->[0] => 1 }
        @{ $dbh->selectall_arrayref('SELECT idArticulo FROM articulos') };

    $dbh->do(q{
        CREATE TABLE IF NOT EXISTS ventas (
            idVenta           INTEGER PRIMARY KEY,
            idComprador       INTEGER NOT NULL,
            idArticulo        INTEGER NOT NULL,
            cantidadProductos INTEGER NOT NULL,
            precioTotal       REAL    NOT NULL,
            FOREIGN KEY (idComprador) REFERENCES personas(numeroDocumento),
            FOREIGN KEY (idArticulo)  REFERENCES articulos(idArticulo)
        )
    });
    $dbh->do('DELETE FROM ventas');

    my $sth = $dbh->prepare('INSERT OR REPLACE INTO ventas VALUES (?,?,?,?,?)');
    my ($ok, $skip_clean, $skip_fk) = (0, 0, 0);
    $dbh->begin_work;
    for my $doc (@docs) {
        my $id_venta     = limpiar_valor_numerico($doc->{idVenta});
        my $id_comprador = limpiar_valor_numerico($doc->{idComprador});
        my $id_articulo  = limpiar_valor_numerico($doc->{idArticulo});
        my $cantidad     = limpiar_valor_numerico($doc->{cantidadProductos});
        unless (defined $id_comprador && defined $id_articulo && defined $cantidad) {
            $skip_clean++; next;
        }
        unless (exists $ids_personas{$id_comprador} && exists $ids_articulos{$id_articulo}) {
            $skip_fk++; next;
        }
        $sth->execute($id_venta, $id_comprador, $id_articulo, $cantidad, $doc->{precioTotal} + 0);
        $ok++;
    }
    $dbh->commit;
    log_debug("ETL ventas: $ok insertadas, $skip_clean desc. limpieza, $skip_fk desc. FK");
    return ($ok, $skip_clean, $skip_fk);
}

# Endpoint POST /etl — limpia las tablas SQLite y ejecuta el proceso ETL completo
post '/etl' => sub {
    my $c = shift;
    eval {
        my $dbh = get_sqlite();
        eval { $dbh->do('DELETE FROM ventas') };
        eval { $dbh->do('DELETE FROM articulos') };
        eval { $dbh->do('DELETE FROM personas') };

        my ($art_ok, $art_skip)                      = etl_process_articulos();
        my ($per_ok, $per_skip)                      = etl_process_personas();
        my ($ven_ok, $ven_skip_clean, $ven_skip_fk)  = etl_process_ventas();

        $c->render(json => {
            status    => 'ok',
            articulos => { insertados => $art_ok,  descartados          => $art_skip },
            personas  => { insertadas => $per_ok,  descartadas          => $per_skip },
            ventas    => {
                insertadas           => $ven_ok,
                descartadas_limpieza => $ven_skip_clean,
                descartadas_fk       => $ven_skip_fk,
            },
        });
    };
    if ($@) {
        log_debug("Error ETL: $@");
        $c->render(json => { status => 'error', message => "$@" }, status => 500);
    }
};

# Rutas para cargar datos
get '/load_data' => sub {

};

# Rutas para obtener datos de MongoDB
get '/mongo/personas' => sub {
    my $c          = shift;
    my $client     = MongoDB::MongoClient->new(host => 'mongodb://mongodb_personas:27017');
    my $collection = $client->get_database('almacen')->get_collection('personas');
    my @docs       = $collection->find()->all();
    for my $doc (@docs) { delete $doc->{_id} }
    $c->render(json => \@docs);
};

get '/mongo/articulos' => sub {
    my $c          = shift;
    my $client     = MongoDB::MongoClient->new(host => 'mongodb://mongodb_articulos:27017');
    my $collection = $client->get_database('almacen')->get_collection('articulos');
    my @docs       = $collection->find()->all();
    for my $doc (@docs) { delete $doc->{_id} }
    $c->render(json => \@docs);
};

get '/mongo/ventas' => sub {
    my $c          = shift;
    my $client     = MongoDB::MongoClient->new(host => 'mongodb://mongodb_ventas:27017');
    my $collection = $client->get_database('almacen')->get_collection('ventas');
    my @docs       = $collection->find()->all();
    for my $doc (@docs) { delete $doc->{_id} }
    $c->render(json => \@docs);
};

# Rutas para obtener datos de SQLite
get '/sqlite/personas' => sub {
    my $c    = shift;
    my $dbh  = get_sqlite();
    my $rows = $dbh->selectall_arrayref('SELECT * FROM personas', { Slice => {} });
    $c->render(json => $rows);
};

get '/sqlite/articulos' => sub {
    my $c    = shift;
    my $dbh  = get_sqlite();
    my $rows = $dbh->selectall_arrayref('SELECT * FROM articulos', { Slice => {} });
    $c->render(json => $rows);
};

get '/sqlite/ventas' => sub {
    my $c    = shift;
    my $dbh  = get_sqlite();
    my $rows = $dbh->selectall_arrayref('SELECT * FROM ventas', { Slice => {} });
    $c->render(json => $rows);
};

# Agregar una nueva persona
post '/sqlite/personas' => sub {
    my $c    = shift;
    my $data = $c->req->json;
    my $dbh  = get_sqlite();
    eval {
        $dbh->do(
            'INSERT INTO personas (numeroDocumento,nombres,primerApellido,segundoApellido,fechaNacimiento,telefono,direccion,email) VALUES (?,?,?,?,?,?,?,?)',
            undef,
            $data->{numeroDocumento}, $data->{nombres},        $data->{primerApellido},
            $data->{segundoApellido}, $data->{fechaNacimiento}, $data->{telefono},
            $data->{direccion},       $data->{email}
        );
        $c->render(json => { status => 'ok', numeroDocumento => $data->{numeroDocumento} });
    };
    $c->render(json => { status => 'error', message => "$@" }, status => 400) if $@;
};

# Agregar un nuevo artículo
post '/sqlite/articulos' => sub {
    my $c    = shift;
    my $data = $c->req->json;
    my $dbh  = get_sqlite();
    eval {
        $dbh->do(
            'INSERT INTO articulos (idArticulo,nombreArticulo,precioArticulo,cantidadArticulo) VALUES (?,?,?,?)',
            undef,
            $data->{idArticulo}, $data->{nombreArticulo},
            $data->{precioArticulo}, $data->{cantidadArticulo}
        );
        $c->render(json => { status => 'ok', idArticulo => $data->{idArticulo} });
    };
    $c->render(json => { status => 'error', message => "$@" }, status => 400) if $@;
};

# Agregar una nueva venta
post '/sqlite/ventas' => sub {
    my $c    = shift;
    my $data = $c->req->json;
    my $dbh  = get_sqlite();
    eval {
        $dbh->do(
            'INSERT INTO ventas (idVenta,idComprador,idArticulo,cantidadProductos,precioTotal) VALUES (?,?,?,?,?)',
            undef,
            $data->{idVenta},     $data->{idComprador}, $data->{idArticulo},
            $data->{cantidadProductos}, $data->{precioTotal}
        );
        $c->render(json => { status => 'ok', idVenta => $data->{idVenta} });
    };
    $c->render(json => { status => 'error', message => "$@" }, status => 400) if $@;
};


# Iniciar la aplicación Mojolicious
app->start;

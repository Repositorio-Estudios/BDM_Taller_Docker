use Mojolicious::Lite;
use DBI;
use MongoDB;
use JSON;
use File::Slurp;
use Data::Dumper;
use Mojo::JSON qw(decode_json);
use Mojo::UserAgent;


# Conectar a la base de datos SQLite


# Conectar a MongoDB para cada colección en sus respectivos contenedores


# Función para cargar datos desde archivos JSON a MongoDB
sub load_data_to_mongo {

}

# Función para registrar mensajes de depuración
sub log_debug {
    my ($message) = @_;
    my $log_file = '/app/data/debug.log';  # Especifica la ruta completa al archivo de log
    open my $fh, '>>', $log_file or die "No se puede abrir el archivo: $!";
    print $fh localtime() . " - $message\n";  # Incluye timestamp
    close $fh;
}


# Función para extraer y cargar personas
sub etl_process_personas {
    
}


# Función para extraer y cargar artículos
sub etl_process_articulos {
 
}

# Función para extraer y cargar ventas
sub etl_process_ventas {
 
}

# Endpoint POST 
post '/etl' => sub {
    
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

};

get '/sqlite/articulos' => sub {

};

get '/sqlite/ventas' => sub {

};

# Agregar una nueva persona
post '/sqlite/personas' => sub {
    
};

# Agregar un nuevo artículo
post '/sqlite/articulos' => sub {
 
};

# Agregar una nueva venta
post '/sqlite/ventas' => sub {

};


# Iniciar la aplicación Mojolicious
app->start;

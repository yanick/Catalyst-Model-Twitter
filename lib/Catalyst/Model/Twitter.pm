package Catalyst::Model::Twitter;
use Moose;
use namespace::autoclean;
use Try::Tiny;
use Net::Twitter;
use Carp;
use Data::Dumper;
extends 'Catalyst::Model';

has 'traits' => (
    is => 'rw',
    isa => 'ArrayRef',
    lazy => 1,
    default => sub {[]}
);

has 'consumer_key' => (
    is       => 'rw',
    isa      => 'Str',
    required => 0,
    default  => sub { croak "Must provide consumer_key" },
    lazy     => 1,
);

has 'consumer_secret' => (
    is       => 'rw',
    isa      => 'Str',
    required => 0,
    default  => sub { croak "Must provide consumer_secret" },
    lazy     => 1,
);

has 'nt' => (
    is         => 'ro',
    isa        => 'Net::Twitter',
    required   => 1,
    lazy_build => 1,
);

sub _build_nt {
    my $self = shift;
    return Net::Twitter->new(
        traits          => $self->traits,
        consumer_key    => $self->consumer_key,
        consumer_secret => $self->consumer_secret,
    );
}

sub auth_data {
    my ( $self, $opts ) = @_;
    my $url;
    my $nt = $self->nt;
    my $auth_hash;
    try {
        $auth_hash->{'url'} =
          $nt->get_authentication_url( callback => $opts->{'callback'} );
    }
    catch {
        $auth_hash->{'error'} = "Couldn't authenticate: $_";
    };

    $auth_hash->{'oauth_secret'} = $nt->request_token_secret;
    return $auth_hash;

}

sub do_auth {
    my ( $self, $opts ) = @_;
    my $auth_hash;
    my $nt = $self->nt;
    warn "opts: " . Dumper $opts; 
    $nt->request_token( $opts->{'request_token'} );
    $nt->request_token_secret( $opts->{'request_token_secret'} );

    my ( $access_token, $access_secret, $user_id, $screen_name ) =
      @{$auth_hash}{qw/access_token access_secret user_id screen_name/} = try {
        $nt->request_access_token(
            verifier => $opts->{'verifier'} );
      };

    if ($access_token) {
        $auth_hash->{'access_token'} = $access_token;
        $auth_hash->{'twitter_user'} = try {
            $nt->verify_credentials( { user_id => $user_id } );
        }
        catch {
            $auth_hash->{'error'} = "Twitter error: $_";
        };
    }

    return $auth_hash;
}

__PACKAGE__->meta->make_immutable;
1;

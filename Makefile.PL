use inc::Module::Install;

# Define metadata
name            'Test-Chimps-Client';
all_from        'lib/Test/Chimps/Client.pm';

# Specific dependencies
requires('Class::Accessor');
requires('DBI');
requires('LWP::UserAgent');
requires('HTTP::Request::Common');
requires('Params::Validate');
requires('TAP::Harness::Archive');
requires('YAML::Syck');

build_requires('Test::Dependencies');

auto_install;
WriteAll;

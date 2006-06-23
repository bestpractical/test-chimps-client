use inc::Module::Install;

# Define metadata
name            'Test-Chimps';
all_from        'lib/Test/Chimps.pm';

# Specific dependencies
requires('Algorithm::TokenBucket');
requires('Date::Parse');
requires('DateTime');
requires('HTML::Mason');
requires('LWP::UserAgent');
requires('Module::CoreList');
requires('Params::Validate');
requires('Test::Dependencies');
requires('Test::TAP::HTMLMatrix');
requires('Test::TAP::Model::Visual');
requires('YAML::Syck');

auto_install;
WriteAll;

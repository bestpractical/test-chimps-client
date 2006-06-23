use inc::Module::Install;

# Define metadata
name            'Test-Smoke-Report';
all_from        'lib/Test/Smoke/Report.pm';

# Specific dependencies
requires('Algorithm::TokenBucket');
requires('Date::Parse');
requires('DateTime');
requires('HTML::Mason');
requires('LWP::UserAgent');
requires('Module::CoreList');
requires('Params::Validate');
requires('Test::TAP::HTMLMatrix');
requires('Test::TAP::Model::Visual');
requires('YAML::Syck');


no_index        'directory'         => 'demos';

auto_install;
WriteAll;

use inc::Module::Install;
all_from        'lib/Test/Chimps/Client.pm';
readme_from     'lib/Test/Chimps/Client.pm';

# Specific dependencies
requires('Class::Accessor');
requires('DBI');
requires('Cwd');
requires('Scalar::Util');
requires('LWP::UserAgent');
requires('HTTP::Request::Common');
requires('Params::Validate');
requires('TAP::Harness::Archive');
requires('YAML::Syck');

build_requires('Test::Dependencies');

auto_install;
WriteAll;

use inc::Module::Install;
all_from        'lib/Test/Chimps/Client.pm';
readme_from     'lib/Test/Chimps/Client.pm';

# Specific dependencies
requires('Class::Accessor');
requires('Cwd');
requires('File::Spec');
requires('File::Path');
requires('File::Temp');
requires('Scalar::Util');
requires('LWP::UserAgent');
requires('HTTP::Request::Common');
requires('Params::Validate');
requires('TAP::Harness::Archive');
requires('YAML::Syck');

tests('t/*.t t/*/*.t');
extra_tests;

build_requires('Test::Dependencies');
build_requires('Test::HTTP::Server::Simple');
build_requires('HTTP::Server::Simple::CGI');

auto_install;
WriteAll;

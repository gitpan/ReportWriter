use Module::Build;
my $build = Module::Build->new (
  module_name => 'Business::ReportWriter',
  dist_author => 'Kaare Rasmussen <kar at kakidata.dk>',
  dist_abstract => 'A Business Oriented ReportWriter. Currently supports PDF and OpenOffice Calc.',
  dist_version => '0.06',
  license => 'perl',
  requires => {
    'perl'                         => '5.8.3',
    'PDF::API2'                    => '0.40',
    'OpenOffice::OOBuilder'        => '0'
  },
);
$build->create_build_script;

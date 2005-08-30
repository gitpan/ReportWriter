package Business::ReportWriter::OOCalc;

use POSIX qw(setlocale LC_NUMERIC);
use utf8;
use OpenOffice::OOCBuilder;

use Business::ReportWriter;

@ISA = ("Business::ReportWriter");

sub initLine {
  my ($self, $rec) = @_;
  $self->{rownr}++;
  $self->{fieldnr} = 0;
}

sub outField {
  my ($self, $text, $field) = @_;
  $self->{fieldnr}++;
  $self->outText($text);
}

sub initList {
  my ($self) = @_;
  my $sheet=OpenOffice::OOCBuilder->new();
  $self->{sheet} = $sheet;
}

sub printDoc {
  my ($self, $filename) = @_;
  my $sheet = $self->{sheet};
  if ($filename) {
    $sheet->generate ($filename)
  }
}

sub outText {
  my ($self, $text) = @_;
  my $sheet = $self->{sheet};
  $sheet->goto_xy($self->{fieldnr}, $self->{rownr});
  utf8::decode($text);
  $sheet->set_data($text);
  print "$self->{rownr} $self->{fieldnr}: $text\n";
}

1;

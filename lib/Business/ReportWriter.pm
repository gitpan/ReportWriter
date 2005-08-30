package Business::ReportWriter;

use POSIX qw(setlocale LC_NUMERIC);
##
use Data::Dumper;
##

sub new {
  my ($class, %parms) = @_;
  my $self = {};
  $self = bless $self,$class;
  return $self;
}

sub processReport {
  my ($self, $outfile, $report, $head, $list) = @_;
  my %report = %$report;
  my @list = @$list;
  push @list, {} if $#list < 1;

  $self->reportInit( $report{report} );
  $self->pageHeader( $report{page}{header} );
  $self->body( $report{body} );
  $self->graphics( $report{graphics} );
  $self->logos( $report{page}{logo} );
  $self->breaks( $report{breaks} );
  $self->fields( $report{fields} );
  $self->printList(\@list, \%$head );
  return $outfile ? $self->printDoc($outfile) : $self->get_doc;
}

sub reportInit {
  my ($self, $parms) = @_;
  $self->{report} = $parms;
}

sub pageHeader {
  my ($self, $parms) = @_;
  $self->{report}{page} = $parms;
}

sub body {
  my ($self, $parms) = @_;
  $self->{report}{body} = $parms;
}

sub graphics {
  my ($self, $parms) = @_;
  $self->{report}{graphics} = $parms;
}

sub fieldHeaders {
  my ($self, $fh) = @_;

  if ($fh->{show} ne 'off') {
    for (@{ $self->{report}{fields} }) {
      $self->outField($_->{text}, $_, $fh);
    }
  }
}

sub logos {
  my ($self, $parms) = @_;
  $self->{report}{logo} = $parms;
}

sub fields {
  my ($self, $parms) = @_;
  $self->{report}{fields} = $parms;
}

sub breaks {
  my ($self, $parms) = @_;
  $self->{report}{breaks} = $parms;
  my @breakorder;
  for (keys %$parms) {
    $breakorder[$parms->{$_}{order}] = $_;
  }
  $self->{report}{breaks}{_order} = [ @breakorder ];
}

# Report writing
sub initBreak {
}

sub initLine {
}

sub initField {
}

sub outField {
}

sub break_fields {
  my ($self, $break_name, $tot) = @_;
  my $name = $tot->{name};
  my $rec = $self->{totals}{$break_name};

  $self->process_field($tot, $rec);
  $self->{totals}{$break_name}{$name} = 0;
}

sub process_break {
  my ($self, $break_name) = @_;
  my $p = $self->{pdf};

  my $break = $self->{report}{breaks}{$break_name};
  $self->initLine($break);

  if (defined($break->{total})) {
    foreach my $tot (@{ $break->{total} }) {
      $self->break_fields($break_name, $tot);
    }
  }
}

sub printBreakheader {
  my ($self, $rec, $break_name) = @_;
  my $p = $self->{pdf};
  my $break = $self->{report}{breaks}{$break_name};

  $self->initBreak($rec, $break);
  $self->initLine($rec, $break->{header});
  for my $bh (@{ $break->{header}{text} }) {
    $self->process_field($bh, $rec);
  }

  $self->initLine($rec, $break->{header}{FieldHeaders});
  $self->fieldHeaders($break->{header}{FieldHeaders});
}

sub printBreak {
  my $self = shift;

  for my $break_name (@{ $self->{report}{breaks}{_order} }) {
    my $self_break = $self->{breaks}{$break_name} || '';
    if ($self_break eq '_break') {
      $self->process_break($break_name);
    }
  }
}

sub process_field {
  my ($self, $fld, $rec) = @_;

  return if (defined($fld->{depends}) && 
    !eval($self -> make_text($rec, $fld->{depends})));
  my $text = defined($fld->{function}) ?
    $self->make_func($rec, $fld->{function}) :
    $self->make_text($rec, $fld->{text});
  $self->outField($text, $fld) if $text;
}


sub make_fieldtext {
  my ($self, $rec, $text) = @_;
  my @fields = ($text =~ /(\w*)/g);
  for my $field (@fields) {
    $text =~ s/$field/$rec->{$field}/eg;
  }
  return $text;
}

sub process_linefield {
  my ($self, $fld, $rec) = @_;

  return if (defined($fld->{depends}) && 
    !eval($self -> make_text($rec, $fld->{depends})));
  $self -> initField($fld);
  my $text = defined($fld->{function}) ?
    $self->make_func($rec, $fld->{function}) :
    $self->make_fieldtext($rec, $fld->{name});
  $self->outField($text, $fld) if $text;
}

sub textarray {
  my ($self, $fld, $rec) = @_;

  for (@{ $rec->{$fld->{name}} }) {
    $self -> initField($fld);
    $self->outField($_, $fld) if $_;
  }
}

sub printLine {
  my ($self, $rec) = @_;

  $self -> initLine($rec);
  for (@{ $self->{report}{fields} }) {
    $self->textarray($_, $rec), next if lc($_->{fieldtype}) eq 'textarray';
    $self->process_linefield($_, $rec);
  }
}

sub sumTotals {
  my $self = shift;
  my $rec = shift;
  for my $break (@{ $self->{report}{breaks}{_order} }) {
    if (defined($self->{report}{breaks}{$break}{total})) {
      foreach my $tot (@{ $self->{report}{breaks}{$break}{total} }) {
        my $name = $tot->{name};
        $self->{totals}{$break}{$name} += $rec->{$name};
      }
    }
  }
}

sub checkforBreak {
  my ($self, $rec, $last) = @_;
  my $brk = '';
  for my $break (reverse @{ $self->{report}{breaks}{_order} }) {
    my $self_break = $self->{breaks}{$break} || '';
    my $rec_break = $rec->{$break} || '';
    if (($last && !($break eq '_page')) || $self_break ne $rec_break) {
      $brk = '_break';
    }
    $self->{breaks}{$break} = $brk if $brk;
  }
}

sub saveBreaks {
  my $self = shift;
  my ($rec, $first) = @_;
  for my $break (reverse @{ $self->{report}{breaks}{_order}}) {
    my $self_break = $self->{breaks}{$break} || '';
    my $rec_break = $rec->{$break} || '';
    $self -> printBreakheader($rec, $break)
      if ($first and $break ne '_total' and $break ne '_page')
      || $self_break ne $rec_break;
    $self->{breaks}{$break} = $rec->{$break};
  }
}

sub processTotals {
  my $self = shift;
  my $rec = shift;
  my $first = (!defined($self->{started}));
  $self->{started} = 1;
  my $last = (ref $rec ne 'HASH');
  $self->printTotals($rec) if !$first;
  $self->saveBreaks($rec, $first) if !$last;
  $self->sumTotals($rec) if !$last;
}

sub initList {
}

sub checkPage {
}

sub printList {
  my ($self, $list, $page) = @_;
  my @list = @$list;
  $self->{pageData} = $page;

  $self->initList;

  foreach my $rec (@list) {
    $self->checkPage;
    $self->processTotals($rec);
    $self->printLine($rec);
  }
  $self->endPrint();
}

sub printTotals {
  my ($self, $rec) = @_;
  my $last = (ref $rec ne 'HASH');
  $self->checkforBreak($rec, $last);
  $self->printBreak();
}

sub endPrint {
  my $self = shift;
  $self -> processTotals();
}
# Support

sub make_text {
  my ($self, $rec, $text) = @_;

  my @fields = ($text =~ /\$(\w*)/g);
  for my $field (@fields) {
    $text =~ s/\$$field/$rec->{$field}/eg;
  }
  return $text;
}

sub make_func {
  my ($self, $rec, $func) = @_;

  my @fields = ($func =~ /\$(\w*)/g);
  for my $field (@fields) {
    $func =~ s/\$$field/\$rec->{$field}/g;
  }
  my $text;
  setlocale(LC_NUMERIC, $self->{report}{locale});
  eval('$text = ' . $func);
  setlocale( LC_NUMERIC, "C" );
  return $text;
}

1;
__END__

=head1 NAME

Business::ReportWriter - A Business Oriented ReportWriter.

=head1 SYNOPSIS

  use Business::ReportWriter::Pdf;

  my $rw = new Business::ReportWriter::Pdf();
  $rw -> processReport($outfile, $report, $head, $list);

=head1 DESCRIPTION

Business::ReportWriter is a tool to make a Business Report from an array of
data.  The report output is generated based on a XML description of the report.

The report is written to a file.

=head2 Method calls

=over 4

=item $obj = new()

Creates a Report Writer Object.

=item $obj -> processReport($outfile, $report, $head, $list)

Creates a PDF Report and writes it to the file named in $outfile. 

$report is a hash reference to the Report Definition.
$head is a hash containing external data (also called Page Data).
$list is a reference to the array that contains the report data.

=back

=head2 Data Description

=head3 report

A hash reference describing the wanted output. Contains these sections:

=over 4

=item report

=back

Hash with report wide information. Possible entries: 

I<locale> - eg us_EN, da_DK...

I<papersize> - A4, Letter...

=head3 breaks
 
A hash defining the line breaks / report totals. Hash key is the name of
the field to totl, pointing to a new hash containing 

I<order> Sort order of break, starting from 0. Must be unique.

I<font> Font used for the break line. Font is a hash containing face and size.

I<format> printf-like format string.

I<text> Print text for the total line. Any word beginning with a $ character
will be replaced with the corresponding field name.

I<xpos> Horisontal position of the text.

I<total> Array telling which fields are to be totalled.

There are two special break names:


I<_page> will result in a total for each page and _total will give a grand
total at the end of the report.

=head3 fields
 
Array of hashes describing all fields in the body area of the report.
Each element can contain 

I<font> Same as in the breaks section.

I<name> Field name - corresponds to the hash in the Data List.

I<text> Same as in the breaks section.

I<xpos> Same as in the breaks section.

I<align> Alignment of field. Possible values are left, center, right.

I<format> Same as in the breaks section.

I<function> A perl function to replace the field as output. Any word beginning
with a $ character will be replaced by a field.

I<depends> A perl expression. If true, the field will be printed, if false it
will not. Any word beginning with a $ character will be replaced by a field.

=head3 page
 
Hash describing the report outside the body area. Entries are 

I<header> - a hash describing the header. There can be a font entry and then
there's an array containing text elements, each of which can contain depends,
function, text, align, xpos and ypos. These elements do what you'd expect
them to. sameline will allow you to skip xpos and let it inherit ypos from
the previous entry- very useful if there is a depends entry.

I<logo> Telling where to find the logo and where to place it.

Contains a hash with key logo including an array with image descriptions.
Name is the file name including path information, x an y gives upper left corner
and scale indicates which factor to scale the image with.

=head3 body
 
A hash describing the body area (where the report list will go). Contains 

I<font> (well known by now), ypos telling upper edge of the body and heigth

=head3 graphics
 
A hash entry with key width telling line width and a hash with key boxes
containing an array describing ``line graphics'' or boxes. Each box is
defined with the values topx, topy, bottomx and bottomy. 

=head2 Page Data

A hash reference to data that can be used in the page region of the report.
B<pagenr> is automatically included and updated.

=head2 List Data

Array of hash. Each array element represents one line in the final report.
The hash keys can be referenced in the report definition.

=head1 AUTHOR

Kaare Rasmussen <kar at kakidata.dk>

package Pdf;

use strict;
use warnings;
use PDF::API2;

my %DEFAULTS = (
  PageSize => 'A4',
  PageOrientation => 'Portrait',
  Compression => 1,
  PdfVersion => 3,
  marginX => 30,
  marginY => 30,
  font => "Helvetica",
  size => 12,
);

my ( $day, $month, $year )= ( localtime( time ) )[3..5];
my $DATE=sprintf "%02d/%02d/%04d", ++$month, $day, 1900 + $year;

my %INFO =
          (
            Creator => "None",
            Producer => "None",
            CreationDate => $DATE,
            Title => "Untitled",
            Subject => "None",
            Author => "Auto-generated",
          );

my @parameterlist=qw(
        PageSize
        PageWidth
        PageHeight
        PageOrientation
        Compression
        PdfVersion
);

sub new {
  my $class    = shift;
  my %defaults = @_;

  foreach my $dflt (@parameterlist) {
    if (defined($defaults{$dflt})) {
      $DEFAULTS{$dflt} = $defaults{$dflt}; # Overridden from user
    }
  }

  # Set the width and height of the page
  my ($x1, $y1, $pageWidth, $pageHeight) =
    PDF::API2::Util::page_size($DEFAULTS{PageSize});

  # Swap w and h if landscape
  if (lc($DEFAULTS{PageOrientation})=~/landscape/) {
    my $tempW = $pageWidth;
    $pageWidth = $pageHeight;
    $pageHeight = $tempW;
    $tempW = undef;
  }

  my $MARGINX = $DEFAULTS{marginX};
  my $MARGINY = $DEFAULTS{marginY};

  # May not need alot of these, will review later
  my $self= { #pdf          => PDF::API2->new(),
              hPos         => undef,
              vPos         => undef,
              size         => 12,    # Default
              font         => undef, # the font object
              PageWidth    => $pageWidth,
              PageHeight   => $pageHeight,
              Xmargin      => $MARGINX,
              Ymargin      => $MARGINY,
              BodyWidth    => $pageWidth - $MARGINX * 2,
              BodyHeight   => $pageHeight - $MARGINY * 2,
              page         => undef, # the current page object
              page_nbr     => 1,
              align        => 'left',
              linewidth    => 1,
              linespacing  => 0,
              FtrFontName  => 'Helvetica-Bold',
              FtrFontSize  => 11,
              MARGIN_DEBUG => 0,
              PDF_API2_VERSION => $PDF::API2::VERSION,

              ########################################################
              # Cache for font object caching -- used by setFont() ###
              ########################################################
             __font_cache => {},
            };

  if (length($defaults{File})) {
    $self->{pdf} = PDF::API2->open($defaults{File})
                     or die "$defaults{File} not found: $!\n";

  } else {
    $self->{pdf} = PDF::API2->new();
  }

  # Default fonts
  $self->{font} = $self->{pdf}->corefont('Helvetica'); # Default font object
  #$self->{font}->encode('latin1');

  # Set the users options
  foreach my $key (keys %defaults) {
    $self->{$key}=$defaults{$key};
  }

  bless $self, $class;

  return $self;
}

sub pages {
  my $self = shift;

  return $self->{pdf}->pages;
}

sub newpage {
  my $self = shift;
  my $no_page_number = shift;

  # make a new page
  $self->{page} = $self->{pdf}->page;
  $self->{page}->mediabox($self->{PageWidth}, $self->{PageHeight});

  # Handle the page numbering if this page is to be numbered
  my $total = $self->pages;
  push(@{$self->{no_page_num}}, $no_page_number);

  $self->{page_nbr}++;
  return(0);
}

sub getPageDimensions {
  my $self = shift;

  return($self->{PageWidth}, $self->{PageHeight});
}

sub setSize {
  my ( $self, $size ) = @_;

  $self->{size} = $size;
}

sub setFont {
  my ( $self, $font, $size )= @_;

  if (exists $self->{__font_cache}->{$font}) {
    $self->{font} = $self->{__font_cache}->{$font};
  }
  else {
    $self->{font} = $self->{pdf}->corefont($font);
    $self->{__font_cache}->{$font} = $self->{font};
  }

  $self->{fontname} = $font;
}

sub getAddTextPos {
  my ($self) = @_;
  return($self->{hPos}, $self->{vPos});
}

sub getStringWidth {
  my $self = shift;
  my $String = shift;

  my $txt = $self->{page}->text;
  $txt->font($self->{font}, $self->{size});
  return $txt->advancewidth($String);
}

sub drawLine {
  my ( $self, $x1, $y1, $x2, $y2 ) = @_;

  my $gfx = $self->{page}->gfx;
  $gfx->move($x1, $y1);
  $gfx->linewidth($self->{linewidth});
  $gfx->linewidth(.1);
  $gfx->line($x2, $y2);
  $gfx->stroke;
}

sub drawRect {
  my ( $self, $x1, $y1, $x2, $y2 ) = @_;

  my $gfx = $self->{page}->gfx;
  $gfx->linewidth($self->{linewidth});
  $gfx->rectxy($x1, $y1, $x2, $y2);
  $gfx->stroke;
}

sub shadeRect {
  my ( $self, $x1, $y1, $x2, $y2, $color ) = @_;

  my $gfx = $self->{page}->gfx;

  $gfx->fillcolor($color);
  $gfx->rectxy($x1, $y1, $x2, $y2);
  $gfx->fill;
  $gfx->fillcolor('black');
}

sub setGfxLineWidth {
  my ( $self, $width ) = @_;

  $self->{linewidth} = $width;
}

sub addImgScaled {
  my ( $self, $file, $x, $y, $scale ) = @_;

   $self->addImg($file, $x, $y, $scale);
}

sub addImg {
  my ( $self, $file, $x, $y, $scale ) = @_;

  my %type = (jpeg => "jpeg",
              jpg  => "jpeg",
              tif  => "tiff",
              tiff => "tiff",
              pnm  => "pnm",
              gif  => "gif",
              png  => "png",
  );

  $file =~ /\.(\w+)$/;
  my $ext = $1;

  my $sub = "image_$type{$ext}";
  my $img = $self->{pdf}->$sub($file);
  my $gfx = $self->{page}->gfx;

  $gfx->image($img, $x, $y, $scale);
}

sub setTextcolor {
  my ( $self, $color ) = @_;
  $self->{textcolor} = $color;
}

sub addParagraph {
  my ( $self, $text, $hPos, $vPos, $width, $height, $indent, $lead ) = @_;

  my $txt = $self->{page}->text;
  $txt->font($self->{font}, $self->{size});

  my $textcolor = $self->{textcolor} || 'black';
  $txt->fillcolor($textcolor);
  $txt->lead($lead); # Line spacing
  $txt->translate($hPos,$vPos);
  $txt->paragraph($text, $width, $height, -align=>'justified');

  ($self->{hPos},$self->{vPos}) = $txt->textpos;
}

sub Finish {
  my $self = shift;
  my $callback = shift;

  my $total = $self->{page_nbr} - 1;

  # Call the callback if one was given to us
  if (ref($callback) eq 'CODE') {
    &$callback($self, $total);
  # This will print a footer if no $callback is passed for backwards
  # compatibility
  } elsif ($callback !~ /none/i) {
    &gen_page_footer($self, $total, $callback);
  }

  $self->{pdf}->info(%INFO);
  my $out = $self->{pdf}->stringify;

  return $out;
}

package Business::ReportWriter::Pdf;

use strict;
use warnings;
use POSIX qw(setlocale LC_NUMERIC);
use utf8;

use Business::ReportWriter;

##
use Data::Dumper;
##

our @ISA = ("Business::ReportWriter");

sub fields {
  my ($self, $parms) = @_;
  $self->SUPER::fields($parms);
  my @fields = @$parms if $parms;
# Find maximum line height
  $self->{font}{maxheight} = 8;
  for (0..$#{ $self->{report}{fields} }) {
    $self->{fields}{$fields[$_]{name}} = $_;
    if (defined($fields[$_]{font}{size}) &&
      $fields[$_]{font}{size} > $self->{font}{_maxheight}) {
      $self->{font}{_maxheight} = $fields[$_]{font}{size};
    }
  }
}

sub breaks {
  my ($self, $parms) = @_;

  $self->SUPER::breaks($parms);

# Find total break height
$|=1;

  for (keys %$parms) {
    next if /^_/;
    my $brk = $parms->{$_};
    my $hbs = $brk->{beforespace} || 0;
    my $hts = 10;
    my $hfhs = 10;
    my $ts = 10;
#    $self->{fields}{$fields[$_]{name}} = $_;
#    if (defined($fields[$_]{font}{size}) &&
#      $fields[$_]{font}{size} > $self->{font}{_maxheight}) {
#      $self->{font}{_maxheight} = $fields[$_]{font}{size};
#    }
    $brk->{breakheight} = $hbs + $hts + $hfhs + $ts;
  }
}


# Routines for report writing
sub calcYoffset {
  my ($self, $fontsize) = @_;
  $self->{ypos} -= $fontsize + 2;
  $self->checkPage;
  return $self->{ypos};
}

sub page_footer {
  my ($self, $fontsize) = @_;
  my $break = '_page';
  $self->{breaks}{$break} = '_break';
  my $text = $self->make_text(0, $self->{report}{breaks}{$break}{text});
  $self->{breaktext}{$break} = $text;
  #$self->printBreak();
  $self->{breaks}{$break} = "";
}

sub headerText {
  my $self = shift;
  my $page = $self->{pageData};

  for my $th (@{ $self->{report}{page}{text} }) {
    $self->process_field($th, $page);
  }
}

sub printPageNumber {
  my $self = shift;
  my $page = $self->{report}{page};

  my $text = $page->{number}{text}.$self->{pageData}{pagenr};
  $self->outField($text, $page->{number});
  $self->calcYoffset($self->{font}{size}) unless $page->{number}{sameline};
}

sub printPageheader {
  my $self = shift;
  my $page = $self->{pageData};

  $self->{ypos} = $self->{paper}{topmargen} -
    mmtoPt($self->{report}{page}{number}{ypos})
    if $page->{number}{ypos};
  $self -> headerText();
  $self->printPageNumber;
}

sub bodyStart {
  my $self = shift;
  my $p = $self->{pdf};
  my $body = $self->{report}{body};

  $self->setFont($body->{font});
  $self->{ypos} = $self->{paper}{topmargen}-mmtoPt($body->{ypos})
    if $body->{ypos};
  my $heigth = mmtoPt($body->{heigth}) if $body->{heigth};
  $heigth += mmtoPt($body->{ypos}) if $body->{ypos};
  $self->{paper}{heigth} = $heigth if $heigth;

  $self->fieldHeaders($body->{FieldHeaders});
}

sub drawGraphics {
  my $self = shift;
  my $p = $self->{pdf};
  my $graphics = $self->{report}{graphics};
  $p->setGfxLineWidth($graphics->{width}+0) if defined($graphics->{width});
  for (@{ $graphics->{boxes} }) {
    my $bottomy = $self->{paper}{topmargen}-mmtoPt($_->{bottomy});
    my $topy = $self->{paper}{topmargen}-mmtoPt($_->{topy});
    $p->drawRect(mmtoPt($_->{topx}), $bottomy, mmtoPt($_->{bottomx}), $topy
    );
  }
}

sub drawLogos {
  my $self = shift;
  my $p = $self->{pdf};
  my $logos = $self->{report}{logo};
  for (@{ $logos->{logo} }) {
    my $x = mmtoPt($_->{x});
    my $y = $self->{paper}{topmargen}-mmtoPt($_->{y});
    $p->addImgScaled($_->{name}, $x, $y, $_->{scale});
  }
}

sub newPage {
  my $self = shift;
  my $p = $self->{pdf};
  $self->{pageData}{pagenr}++;
  $self->{breaks}{'_page'} = "";
  $self->page_footer() if $self->{pageData}{pagenr} > 1;
  $self->{ypos} = $self->{paper}{topmargen};
  $p->newpage;
  $self->setFont($self->{report}{page}{font});
  $self -> printPageheader() if defined($self->{report}{page});
  $self -> bodyStart();
  $self -> drawGraphics();
  $self -> drawLogos();
}

sub text_color {
  my ($self, $color) = @_;
  my $p = $self->{pdf};

  $p->setTextcolor($color);
}

sub set_linecolor {
  my ($self, $fld_fgcolor) = @_;

  my $fgcolor = $fld_fgcolor ? $fld_fgcolor :
    $self->{report}{textcolor} || 'black' ;
  $self->text_color($fgcolor);
}

sub draw_topline {
  my ($self) = @_;
  my $p = $self->{pdf};

  my $width = $self->{paper}{width}-20;
  my $ypos = $self->{ypos}-3;
  $p->drawLine(10, $ypos, $width, $ypos);
}

sub draw_underline {
  my ($self) = @_;
  my $p = $self->{pdf};

  my $width = $self->{paper}{width}-20;
  my $ypos = $self->{ypos}-$self->{font}{size}-3;
  $p->drawLine(10, $ypos, $width, $ypos);
}

sub draw_linebox {
  my ($self, $shade) = @_;
  my $p = $self->{pdf};

  my $width = $self->{paper}{width}-20;
  my $ypos = $self->{ypos}-3;
  my $fontsize = $self->{font}{size}+2;
  $p->shadeRect(10, $ypos, $width, $ypos-$fontsize, $shade)
}

sub initBreak {
  my ($self, $rec, $fld) = @_;

  $self->checkPage($fld->{breakheight});
}

sub initLine {
  my ($self, $rec, $fld) = @_;

  $self->setFont($rec->{font});
  $self->calcYoffset($fld->{beforespace}) if $fld->{beforespace};
  $self->set_linecolor($fld->{fgcolor});
  $self->draw_linebox($fld->{shade}) if $fld->{shade};
  $self->draw_topline if $rec->{topline};
  $self->draw_underline if $rec->{underline};
  $self->calcYoffset($self->{font}{size});
}

sub initField {
  my ($self, $field) = @_;

  $self->setFont($field->{font});
  my $fontsize = $self->{font}{size};
}

sub outField {
  my ($self, $text, $field, $alt) = @_;

  my $font = $alt->{font} || $field->{font};
  $self->setFont($font);
  $self->{ypos} = $self->{paper}{topmargen} - mmtoPt($field->{ypos})
    if $field->{ypos};
  $self -> calcYoffset($self->{font}{size}) if defined($field->{nl}) && $text;
  $self->outText($text, $field->{xpos}, $self->{ypos}, $field->{align});
}

sub setFont {
  my ($self, $font) = @_;
  my $p = $self->{pdf};

  if (defined($font)) {
    if ($font->{size}) {
      my $font_size = $font->{size}+0;
      $p->setSize($font->{size}) if $self->{font}{size} != $font_size;
      $self->{font}{size} = $font_size;
    }
    if ($font->{face}) {
      $p->setFont($font->{face}) if $self->{font}{face} ne $font->{face};
      $self->{font}{face} = $font->{face};
    }
  }
}

sub initList {
  my ($self) = @_;
  my $papersize = $self->{report}{papersize} || 'A4';
  my $orientation = $self->{report}{orientation} || 'Portrait';
  my $p = new Pdf(
    PageSize => $papersize,
    PageOrientation => $orientation
  );

  $self->{pdf} = $p;
  $self->{ypos} = -1;
  $self -> paperSize();
}

sub checkPage {
  my ($self, $yplus) = @_;
  my $bottommargen = $self->{paper}{topmargen} - $self->{paper}{heigth};
  $self->newPage() if $self->{ypos} - $yplus < $bottommargen;
}

sub get_doc {
  my ($self) = @_;
  my $p = $self->{pdf};
  $p->Finish("none");
}

sub printDoc {
  my ($self, $filename) = @_;
  my $p = $self->{pdf};
  if ($filename) {
    open OUT, ">$filename";
    print OUT $p->Finish("none");
    close OUT;
  }
}

sub paperSize {
  my $self = shift;
  my $p = $self->{pdf};
  my ($pagewidth, $pageheigth) = $p->getPageDimensions();
  $self->{paper} = {
    width => $pagewidth,
    topmargen => $pageheigth-20,
    heigth => $self->{paper}{topmargen}
  };
}

sub outText {
  my ($self, $text, $x, $y, $align) = @_;
  my $p = $self->{pdf};
  $x = mmtoPt($x);
##
##print "$text er utf8\n" if utf8::is_utf8($text);
##print "$text er ikke utf8\n" unless utf8::is_utf8($text);
utf8::decode($text);
  utf8::decode($text) if utf8::is_utf8($text);
  my $sw = 0;
  $sw = int($p->getStringWidth($text)+.5) if lc($align) eq 'right';
  $x -= $sw;
  my $margen = 20;
  my $width = $self->{paper}{width}-$x-20;
  my $linespace = $self->{font}{size}+2;

  $p->addParagraph($text, $x, $y,
    $self->{paper}{width}-$x-20,
    $self->{paper}{topmargen}-$y, 0, $linespace
  );
  my ($hPos, $vPos) = $p->getAddTextPos();
  $self->{ypos} = $vPos+$linespace if $self->{ypos} < $vPos;
}

sub mmtoPt {
  my $mm = shift;
  return int($mm/.3527777);
}

1;

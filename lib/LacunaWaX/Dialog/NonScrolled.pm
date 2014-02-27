
package LacunaWaX::Dialog::NonScrolled {
    use v5.14;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw();

    use Moose;

    ### Perlapp does not like MooseX::NonMoose::InsideOut one little bit.  
    ### Outside of perlapp it works just fine.
    ###
    ### We'll attempt to at least partially imitate it, by allowing the dialog 
    ### attribute to handle the Wx-y methods, rather than having the actual 
    ### object (LogViewer, Calculator, whatever) extend Wx::Dialog.
    ###
    ### If your extending class needs to call a Wx::Dialog method that's not 
    ### listed below, just add it.
    ###
    ### So your object should still mostly behave as if it were extending 
    ### Wx::Dialog.  The exception is when you need to send a parent object 
    ### along to create another Wx widget; in that case, you must send 
    ### $self->dialog rather than just $self.
    ###
    ### That does not extend to setting up events; $self is fine for that.
    has 'dialog' => (
        is          => 'rw',
        isa         => 'Wx::Dialog',
        lazy_build  => 1,
        handles => {
            Centre              => "Centre",
            Close               => "Close",
            Connect             => "Connect",
            Destroy             => "Destroy",
            EndModal            => "EndModal",
            GetClientSize       => "GetClientSize",
            GetWindowStyleFlag  => "GetWindowStyleFlag",
            Layout              => "Layout",
            SetSize             => "SetSize",
            SetSizer            => "SetSizer",
            SetTitle            => "SetTitle",
            SetWindowStyle      => "SetWindowStyle",
            Show                => "Show",
            ShowModal           => "ShowModal",
        },
    );

    has 'page_sizer'    => (is => 'rw', isa => 'Wx::BoxSizer',  lazy_build => 1, documentation => 'horizontal'  );
    has 'main_sizer'    => (is => 'rw', isa => 'Wx::Sizer',     lazy_build => 1, documentation => 'vertical'    );
    has 'title'         => (is => 'rw', isa => 'Str',           lazy_build => 1);
    has 'position'      => (is => 'rw', isa => 'Wx::Point',     lazy_build => 1);
    has 'size'          => (is => 'rw', isa => 'Wx::Size',      lazy_build => 1);

    sub BUILD {
        my $self = shift;
        return $self;
    }
    sub _build_dialog {#{{{
        my $self = shift;

        my $d = Wx::Dialog->new(
            undef, -1, 
            q{},
            $self->position || Wx::Point->new(10,10),
            $self->size || wxDefaultSize,
            wxRESIZE_BORDER|wxDEFAULT_DIALOG_STYLE
        );

        return $d;
    }#}}}
    sub _build_main_sizer {#{{{
        my $self = shift;
        my $v = wxTheApp->build_sizer($self, wxVERTICAL, 'Main Sizer');
        return $v;
    }#}}}
    sub _build_page_sizer {#{{{
        my $self = shift;
        my $v = wxTheApp->build_sizer($self, wxHORIZONTAL, 'Page Sizer');
        return $v;
    }#}}}
    sub _build_position {#{{{
        my $self = shift;
        return Wx::Point->new(10, 10);
    }#}}}
    sub _build_size {#{{{
        my $self = shift;
        return wxDefaultSize;
    }#}}}
    sub _build_title {#{{{
        my $self = shift;
        return 'Dialog Title';
    }#}}}
    sub _set_events { }

    sub make_non_resizable {#{{{
        my $self = shift;
        my $style = $self->GetWindowStyleFlag;

        $style = ($style ^ wxRESIZE_BORDER);
        $self->SetWindowStyle($style);
        return 1;
    }#}}}
    sub make_resizable {#{{{
        my $self = shift;
        my $style = $self->GetWindowStyleFlag;

        $style = ($style | wxRESIZE_BORDER);
        $self->SetWindowStyle($style);
        return 1;
    }#}}}

    sub init_screen {#{{{
        my $self = shift;

=head2 init_screen

Must be called by your extending class's BUILD sub after everything else is set up.

Just putting the code here inside NonScrolled.pm's BUILD sub does work OK on Windows, 
but does not work OK on Ubuntu.  So don't just arbitrarily think better of this method 
without testing it there first.

=cut

        $self->page_sizer->AddSpacer(5);
        $self->page_sizer->Add($self->main_sizer, 0, 0, 0);
        $self->SetSizer($self->page_sizer);
        $self->Layout;
        return 1;
    }#}}}


    no Moose;
    __PACKAGE__->meta->make_immutable(); 
}

1;

__END__

=head1 NAME

LacunaWaX::Dialog::NonScrolled - A non-scrolled dialog with margins.

=head1 DESCRIPTION

This is not meant to be used on its own; it's meant to be extended to create a 
dialog box with just a scoche of margin.

=head1 SYNOPSIS

 package ExtendingClass;
 use Moose;
 extends 'LacunaWaX::Dialog::NonScrolled';

 # Any Wx components your extending class creates should use $self (a
 # Wx::Dialog) as parent, eg:
 sub _build_button {
  my $self = shift;
  my $b = Wx::Button->new( $self, -1, "Button Text", wxDefaultPosition, wxDefaultSize );
  return $b;
 }

 sub BUILD {
  my $self = shift;

  # title and size attributes are provided by NonScrolled.pm, but you're not
  # likely to enjoy the default values, so your extending class should set
  # its own values.  These attributes are lazy, so your extending class can
  # provide _build_*() methods for them:
  $self->SetTitle( $self->title );
  $self->SetSize( $self->size );

  # main_sizer is a vertical Wx::Sizer provided by NonScrolled.  Your
  # extending class's Wx components should be added to that sizer:
  $self->main_sizer->Add( $self->button, 0, 0, 0 );

  # This sets your main_sizer up inside the provided page_sizer and properly 
  # lays out the page..
  $self->init_screen();

  return $self;
 }
 sub _build_title { return 'My Title' }
 sub _build_size  { return Wx::Size->new($some_width, $some_height) }

 # That main_sizer is itself added to a page_sizer, which maintains the
 # dialog-wide left margin.  This happens automatically, so your extending
 # class does not need to touch page_sizer.

 # Constructor:
 my $object = EXTENDING_CLASS->new(
    app         => $self->app,
    ancestor    => $self->ancestor,
    parent      => $self->parent,
 );

 # Optional - make your dialog non-resizable (default is resizable):
 $object->make_non_resizable;

 # Whoops - crap I didn't mean to do that...
 $object->make_resizable;

=head1 ARGUMENTS

CHECK FIX THIS

=head2 position (optional)

A Wx::Point object defining the NW corner of the dialog.  Defaults to (10,10).

=cut



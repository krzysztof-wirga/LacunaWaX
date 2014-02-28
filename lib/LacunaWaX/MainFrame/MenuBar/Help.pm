
package LacunaWaX::MainFrame::MenuBar::Help {
    use v5.14;
    use Moose;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_MENU);

    with 'LacunaWaX::Roles::MainFrame::MenuBar::Menu';
    use LacunaWaX::Dialog::About;
    use LacunaWaX::Dialog::Help;

    has 'itm_about' => (is => 'rw', isa => 'Wx::MenuItem',  lazy_build => 1);
    has 'itm_help'  => (is => 'rw', isa => 'Wx::MenuItem',  lazy_build => 1);

    sub BUILD {
        my $self = shift;
        $self->Append( $self->itm_about );
        $self->Append( $self->itm_help );
        $self->_set_events();
        return $self;
    }

    sub _build_itm_about {#{{{
        my $self = shift;
        return Wx::MenuItem->new(
            $self->menu, -1,
            '&About',
            'Show about dialog',
            wxITEM_NORMAL,
            undef   # if defined, this is a sub-menu
        );
    }#}}}
    sub _build_itm_help {#{{{
        my $self = shift;
        return Wx::MenuItem->new(
            $self->menu, -1,
            '&Help',
            'Show HTML help',
            wxITEM_NORMAL,
            undef   # if defined, this is a sub-menu
        );
    }#}}}
    sub _set_events {#{{{
        my $self = shift;
        EVT_MENU($self->parent,  $self->itm_about->GetId,   sub{$self->OnAbout(@_)});
        EVT_MENU($self->parent,  $self->itm_help->GetId,    sub{$self->OnHelp(@_)});
        return 1;
    }#}}}

    sub OnAbout {#{{{
        my $self  = shift;
        my $frame = shift;  # Wx::Frame
        my $event = shift;  # Wx::CommandEvent
        my $d = LacunaWaX::Dialog::About->new();
        $d->show();
        return 1;
    }#}}}
    sub OnHelp {#{{{
        my $self  = shift;
        my $frame = shift;  # Wx::Frame
        my $event = shift;  # Wx::CommandEvent
        my $d = LacunaWaX::Dialog::Help->new();
        return 1;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;

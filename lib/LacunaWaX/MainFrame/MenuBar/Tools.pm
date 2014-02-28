
package LacunaWaX::MainFrame::MenuBar::Tools {
    use v5.14;
    use Moose;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_MENU);

    with 'LacunaWaX::Roles::MainFrame::MenuBar::Menu';
    use LacunaWaX::Dialog::Calculator;
    use LacunaWaX::Dialog::LogViewer;
    use LacunaWaX::Dialog::Mail;
    use LacunaWaX::Dialog::SitterManager;
    use LacunaWaX::Dialog::Captcha;

    has 'itm_calc'      => (is => 'rw', isa => 'Wx::MenuItem',  lazy_build => 1);
    has 'itm_logview'   => (is => 'rw', isa => 'Wx::MenuItem',  lazy_build => 1);
    has 'itm_mail'      => (is => 'rw', isa => 'Wx::MenuItem',  lazy_build => 1);
    has 'itm_sitter'    => (is => 'rw', isa => 'Wx::MenuItem',  lazy_build => 1);

    sub FOREIGNBUILDARGS {#{{{
        return; # Wx::Menu->new() takes no arguments
    }#}}}
    sub BUILD {
        my $self = shift;
        $self->Append( $self->itm_calc      );
        $self->Append( $self->itm_logview   );
        $self->Append( $self->itm_mail      );
        $self->Append( $self->itm_sitter    );

        (wxTheApp->server) ? $self->show_connected : $self->show_not_connected;

        $self->_set_events();
        return $self;
    }

    sub _build_itm_calc {#{{{
        my $self = shift;
        return Wx::MenuItem->new(
            $self->menu, -1,
            '&Calculator',
            'Calculator',
            wxITEM_NORMAL,
            undef   # if defined, this is a sub-menu
        );
    }#}}}
    sub _build_itm_logview {#{{{
        my $self = shift;
        return Wx::MenuItem->new(
            $self->menu, -1,
            '&Log Viewer',
            'Log Viewer',
            wxITEM_NORMAL,
            undef   # if defined, this is a sub-menu
        );
    }#}}}
    sub _build_itm_mail {#{{{
        my $self = shift;
        return Wx::MenuItem->new(
            $self->menu, -1,
            '&Mail',
            'Mail',
            wxITEM_NORMAL,
            undef   # if defined, this is a sub-menu
        );
    }#}}}
    sub _build_itm_sitter {#{{{
        my $self = shift;
        return Wx::MenuItem->new(
            $self->menu, -1,
            '&Sitter Manager',
            'Sitter Manager',
            wxITEM_NORMAL,
            undef   # if defined, this is a sub-menu
        );
    }#}}}
    sub _set_events {#{{{
        my $self = shift;
        EVT_MENU($self->parent,  $self->itm_calc->GetId,    sub{$self->OnCalculator(@_)});
        EVT_MENU($self->parent,  $self->itm_logview->GetId, sub{$self->OnLogViewer(@_)});
        EVT_MENU($self->parent,  $self->itm_mail->GetId,    sub{$self->OnMail(@_)});
        EVT_MENU($self->parent,  $self->itm_sitter->GetId,  sub{$self->OnSitterManager(@_)});
        return 1;
    }#}}}


    ### Display or gray out the appropriate menu items based on whether we're 
    ### currently connected or not.  These are not automatic; if we connect or 
    ### disconnect, these need to be called by whatever connected/disconnected 
    ### us.
    sub show_connected {#{{{
        my $self = shift;
        $self->Enable($self->itm_mail->GetId, 1);
        $self->Enable($self->itm_sitter->GetId, 1);
        $self->Enable($self->itm_calc->GetId, 1);
        return 1;
    }#}}}
    sub show_not_connected {#{{{
        my $self = shift;
        $self->Enable($self->itm_mail->GetId, 0);
        $self->Enable($self->itm_sitter->GetId, 0);
        $self->Enable($self->itm_calc->GetId, 0);
        return 1;
    }#}}}

    sub OnCalculator {#{{{
        my $self = shift;

        ### Determine starting point of LogViewer window
        my $tlc         = wxTheApp->get_top_left_corner;
        my $self_origin = Wx::Point->new( $tlc->x + 30, $tlc->y + 30 );
        my $calc = LacunaWaX::Dialog::Calculator->new( 
            parent      => $self->parent,
            position    => $self_origin,
        );
        $calc->Show(1);
        return 1;
    }#}}}
    sub OnLogViewer {#{{{
        my $self = shift;

        ### Determine starting point of LogViewer window
        my $tlc         = wxTheApp->get_top_left_corner;
        my $self_origin = Wx::Point->new( $tlc->x + 30, $tlc->y + 30 );
        my $log_viewer = LacunaWaX::Dialog::LogViewer->new( 
            parent      => $self->parent,
            position    => $self_origin,
        );
        $log_viewer->Show(1);
        return 1;
    }#}}}
    sub OnMail {#{{{
        my $self = shift;

        my $status = LacunaWaX::Dialog::Status->new(
            parent => $self,
            title  => 'Relax',
        );
        $status->show;
        $status->say('The mail tool takes a few seconds to load; be patient, please.');

        my $tlc         = wxTheApp->get_top_left_corner;
        my $self_origin = Wx::Point->new( $tlc->x + 30, $tlc->y + 30 );
        my $mail        = LacunaWaX::Dialog::Mail->new( position => $self_origin );
        $mail->Show(1);

        $status->close();
        return 1;
    }#}}}
    sub OnSitterManager {#{{{
        my $self = shift;

        ### Determine starting point of Sitter Manager window
        my $tlc         = wxTheApp->get_top_left_corner;
        my $self_origin = Wx::Point->new( $tlc->x + 30, $tlc->y + 30 );
        my $sm          = LacunaWaX::Dialog::SitterManager->new( 
            parent      => $self->parent,
            position    => $self_origin,
        );
        $sm->Show(1);
        return 1;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable;
}

1;

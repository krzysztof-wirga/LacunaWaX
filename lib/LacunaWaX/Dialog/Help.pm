
package LacunaWaX::Dialog::Help {
    use v5.14;
    use Data::Dumper;
    use File::Basename;
    use File::Slurp;
    use HTML::Strip;
    use HTML::TreeBuilder::XPath;
    use Lucy::Analysis::PolyAnalyzer;
    use Lucy::Index::Indexer;
    use Lucy::Plan::Schema;
    use Lucy::Plan::FullTextType;
    use Lucy::Search::IndexSearcher;
    use Moose;
    use Template;
    use Try::Tiny;
    use Wx qw(:everything);
    use Wx::Event qw(EVT_BUTTON EVT_CLOSE EVT_HTML_LINK_CLICKED EVT_SIZE EVT_TEXT_ENTER);
    with 'LacunaWaX::Roles::GuiElement';

    use MooseX::NonMoose::InsideOut;
    extends 'Wx::Dialog', 'LacunaWaX::Dialog::NonScrolled';

    has 'sizer_debug' => (is => 'rw', isa => 'Int',  lazy => 1, default => 0,
        documentation => q{
            Turning this on adds extra space usage because of the boxes drawn 
            around the sizers.  This will mess up the sizing on the navbar.
            That's OK, just be aware of it and don't try to fix the navbar sizing 
            while this is on.
        }
    );

    has 'index'         => (is => 'rw', isa => 'Str',       lazy_build => 1);
    has 'history'       => (is => 'rw', isa => 'ArrayRef',  lazy_build => 1);
    has 'history_idx'   => (is => 'rw', isa => 'Int',       lazy_build => 1,
        documentation => q{
            The subscript of the history array containing our current location.
        }
    );
    has 'html_dir' => (is => 'rw', isa => 'Str', lazy_build => 1);
    has 'prev_click_href' => (is => 'rw', isa => 'Str', lazy => 1, default => q{},
        documentation => q{ See OnLinkClicked for details.  }
    );
    has 'summary_length'    => (is => 'rw', isa => 'Int',       lazy => 1,      default => 120  );
    has 'tt'                => (is => 'rw', isa => 'Template',  lazy_build => 1                 );

    has 'title' => (is => 'rw', isa => 'Str',       lazy_build => 1);
    has 'size'  => (is => 'rw', isa => 'Wx::Szie',  lazy_build => 1);

    ### CHECK
    ### On Windows, the bitmapbutton is exactly the same size as the bitmap 
    ### itself.  The wxBU_AUTODRAW style just puts a 1-px border around the 
    ### image.
    ###
    ### On ubuntu, the bitmapbutton itself uses the size assigned (nav_img_h, 
    ### nav_img_w), but it has a bit of neutral border inside the edges before 
    ### it starts displaying the image.
    ###
    ### So any part of your nav image that touches the image borders will be 
    ### turning on wxBU_AUTODRAW will make the buttons on Windows look more 
    ### like the buttons on ubuntu.
    has 'nav_img_h'     => (is => 'rw', isa => 'Int',  lazy => 1, default => 32     );
    has 'nav_img_w'     => (is => 'rw', isa => 'Int',  lazy => 1, default => 32     );
    has 'search_box_h'  => (is => 'rw', isa => 'Int',  lazy => 1, default => 32     );
    has 'search_box_w'  => (is => 'rw', isa => 'Int',  lazy => 1, default => 150    );
    has 'home_spacer_w' => (is => 'rw', isa => 'Int',  lazy => 1, default => 10     );

    has 'bmp_home'          => (is => 'rw', isa => 'Wx::BitmapButton',  lazy_build => 1);
    has 'bmp_left'          => (is => 'rw', isa => 'Wx::BitmapButton',  lazy_build => 1);
    has 'bmp_right'         => (is => 'rw', isa => 'Wx::BitmapButton',  lazy_build => 1);
    has 'bmp_search'        => (is => 'rw', isa => 'Wx::BitmapButton',  lazy_build => 1);
    has 'fs_html'           => (is => 'rw', isa => 'Wx::FileSystem',    lazy_build => 1);
    has 'htm_window'        => (is => 'rw', isa => 'Wx::HtmlWindow',    lazy_build => 1);
    has 'szr_html'          => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => q{vertical});
    has 'szr_navbar'        => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => q{horizontal});
    has 'txt_search'        => (is => 'rw', isa => 'Wx::TextCtrl',      lazy_build => 1, documentation => q{horizontal});

    ### Doesn't follow the Hungarian notation convention used for the other 
    ### WxWindows on purpose, to set it apart from the other controls.    
    ### main_sizer is required by our NonScrolled parent.
    has 'main_sizer' => (is => 'rw', isa => 'Wx::Sizer', lazy_build => 1, documentation => q{vertical});

    sub FOREIGNBUILDARGS {#{{{
        my $self = shift;
        my %args = @_;

        return (
            undef, -1, 
            q{},        # the title
            wxDefaultPosition,
            Wx::Size->new(600, 700),
            wxRESIZE_BORDER|wxDEFAULT_DIALOG_STYLE
        );
    }#}}}
    sub BUILD {
        my($self, @params) = @_;
        $self->Show(0);

        $self->make_index;

        $self->SetTitle( $self->title );
        $self->make_navbar();

        $self->szr_html->Add($self->htm_window, 0, 0, 0);

        $self->main_sizer->Add($self->szr_navbar, 0, 0, 0);
        $self->main_sizer->AddSpacer(5);
        $self->main_sizer->Add($self->szr_html, 0, 0, 0);

        unless( $self->load_html_file($self->index) ) {
            ### Produces an ugly window flash, but since this is something that 
            ### really should never happen, I'm not too concerned about 
            ### momentary ugliness.
            $self->Destroy;
            return;
        }

        $self->init_screen();
        $self->Show(1);
        return $self;
    };
    sub _build_bmp_home {#{{{
        my $self = shift;
        my $img = $self->app->wxbb->resolve(service => '/Assets/images/app/home.png');
        $img->Rescale($self->nav_img_w, $self->nav_img_h);
        my $bmp = Wx::Bitmap->new($img);
        my $v = Wx::BitmapButton->new(
            $self, -1, 
            $bmp,
            wxDefaultPosition,
            Wx::Size->new($self->nav_img_w, $self->nav_img_h),
            wxBU_AUTODRAW 
        );
        return $v;
    }#}}}
    sub _build_bmp_left {#{{{
        my $self = shift;
        my $img = $self->app->wxbb->resolve(service => '/Assets/images/app/arrow-left.png');
        $img->Rescale($self->nav_img_w, $self->nav_img_h);
        my $bmp = Wx::Bitmap->new($img);
        my $v = Wx::BitmapButton->new(
            $self, -1, 
            $bmp,
            wxDefaultPosition,
            Wx::Size->new($self->nav_img_w, $self->nav_img_h),
            wxBU_AUTODRAW 
        );
        return $v;
    }#}}}
    sub _build_bmp_right {#{{{
        my $self = shift;
        my $img = $self->app->wxbb->resolve(service => '/Assets/images/app/arrow-right.png');
        $img->Rescale($self->nav_img_w, $self->nav_img_h);
        my $bmp = Wx::Bitmap->new($img);
        my $v = Wx::BitmapButton->new(
            $self, -1, 
            $bmp,
            wxDefaultPosition,
            Wx::Size->new($self->nav_img_w, $self->nav_img_h),
            wxBU_AUTODRAW 
        );
    }#}}}
    sub _build_bmp_search {#{{{
        my $self = shift;
        my $img = $self->app->wxbb->resolve(service => '/Assets/images/app/search.png');
        $img->Rescale($self->nav_img_w, $self->nav_img_h);
        my $bmp = Wx::Bitmap->new($img);
        my $v = Wx::BitmapButton->new(
            $self, -1, 
            $bmp,
            wxDefaultPosition,
            Wx::Size->new($self->nav_img_w, $self->nav_img_h),
            wxBU_AUTODRAW 
        );
        return $v;
    }#}}}
    sub _build_fs_html {#{{{
        my $self = shift;
        my $v    = Wx::FileSystem->new();
        $v->ChangePathTo( $self->html_dir, 1 );
        return $v;
    }#}}}
    sub _build_history {#{{{
        my $self = shift;
        return [$self->index];
    }#}}}
    sub _build_history_idx {#{{{
        return 0;
    }#}}}
    sub _build_htm_window {#{{{
        my $self = shift;

        #my $w = $self->GetClientSize->width - 10;
        #my $h = $self->GetClientSize->height - 30;

        my $v = Wx::HtmlWindow->new(
            $self, -1, 
            wxDefaultPosition, 
            #Wx::Size->new($w, $h),
            Wx::Size->new($self->get_html_width, $self->get_html_height),
            wxHW_SCROLLBAR_AUTO
        );
        return $v;
    }#}}}
    sub _build_html_dir {#{{{
        my $self = shift;
        return $self->app->bb->resolve(service => '/Directory/html');
    }#}}}
    sub _build_index {#{{{
        return 'index.html';
    }#}}}
    sub _build_size {#{{{
        my $self = shift;
        return Wx::Size->new( 500, 600 );
    }#}}}
    sub _build_szr_main {#{{{
        my $self = shift;
        my $v = $self->build_sizer($self, wxVERTICAL, 'Main Sizer');
        return $v;
    }#}}}
    sub _build_szr_html {#{{{
        my $self = shift;
        my $v = $self->build_sizer($self, wxVERTICAL, 'LacunaWaX Help');
        return $v;
    }#}}}
    sub _build_szr_navbar {#{{{
        my $self = shift;
        my $v = $self->build_sizer($self, wxHORIZONTAL, 'Nav bar');
        return $v;
    }#}}}
    sub _build_title {#{{{
        return 'HTML Window';
    }#}}}
    sub _build_tt {#{{{
        my $self = shift;
        my $tt = Template->new(
            INCLUDE_PATH => $self->html_dir,
            OUTPUT_PATH => $self->html_dir,
            INTERPOLATE => 1,
        );
        return $tt;
    }#}}}
    sub _build_txt_search {#{{{
        my $self = shift;
        my $v = Wx::TextCtrl->new(
            $self, -1, 
            q{},
            wxDefaultPosition, 
            Wx::Size->new($self->search_box_w, $self->search_box_h),
            wxTE_PROCESS_ENTER
        );
        return $v;
    }#}}}
    sub _set_events {#{{{
        my $self = shift;
        EVT_CLOSE(              $self,                              sub{$self->OnClose(@_)}         );
        EVT_BUTTON(             $self,  $self->bmp_home->GetId,     sub{$self->OnHomeNav(@_)}       );
        EVT_BUTTON(             $self,  $self->bmp_left->GetId,     sub{$self->OnLeftNav(@_)}       );
        EVT_BUTTON(             $self,  $self->bmp_right->GetId,    sub{$self->OnRightNav(@_)}      );
        EVT_BUTTON(             $self,  $self->bmp_search->GetId,   sub{$self->OnSearchNav(@_)}     );
        EVT_HTML_LINK_CLICKED(  $self,  $self->htm_window->GetId,   sub{$self->OnLinkClicked(@_)}   );
        EVT_SIZE(               $self,                              sub{$self->OnResize(@_)}        );
        EVT_TEXT_ENTER(         $self,  $self->txt_search->GetId,   sub{$self->OnSearchNav(@_)}     );
    }#}}}

    sub clean_text {#{{{
        my $self = shift;
        my $text = shift;
        $text = " $text";
        $text =~ s/[\r\n]/ /g;
        $text =~ s/\s{2,}/ /g;
        $text =~ s/\s+$//;
        return $text;
    }#}}}
    sub get_docs {#{{{
        my $self    = shift;
        my $kandi   = HTML::Strip->new();
        my $docs    = {};
        my $dir     = $self->app->bb->resolve(service => '/Directory/html');
        foreach my $f(glob("\"$dir\"/*.html")) {
            next if $f =~ /hitlist\.html$/;
            my $html = read_file($f);

            my $content = $kandi->parse( $html );
            $kandi->eof;

            my $x       = HTML::TreeBuilder::XPath->new();
            $x->parse($html);
            my $title   = $x->findvalue('/html/head/title') || 'No Title';
            my $summary = $self->get_doc_summary($x) || 'No Summary';

            $docs->{$f} = {
                content     => $content,
                summary     => $summary,
                title       => $title,
            }
        }
        return $docs;
    }#}}}
    sub get_doc_summary {#{{{
        my $self  = shift;
        my $xpath = shift;

        my @nodeset = $xpath->findnodes('/html/body/*');
        my $summary  = q{};
        NODE:
        for my $n(@nodeset) {
            next if $n->getName =~ /^h/i;   # skip headers
            $summary .= $self->clean_text($n->getValue);
            last NODE if length $summary > $self->summary_length;
        }
        return $summary;
    }#}}}
    sub make_index {#{{{
        my $self = shift;

        my $idx = $self->app->bb->resolve(service => '/Lucy/index');
        return if -e $idx;
        my $docs = $self->get_docs;

        # Create a Schema which defines index fields.
        my $schema = Lucy::Plan::Schema->new;
        my $polyanalyzer = Lucy::Analysis::PolyAnalyzer->new(
            language => 'en',
        );
        my $type = Lucy::Plan::FullTextType->new(
            analyzer => $polyanalyzer,
        );
        $schema->spec_field( name => 'content',     type => $type );
        $schema->spec_field( name => 'filename',    type => $type );
        $schema->spec_field( name => 'summary',     type => $type );
        $schema->spec_field( name => 'title',       type => $type );
        
        # Create the index and add documents.
        my $indexer = Lucy::Index::Indexer->new(
            schema => $schema,  
            index  => $idx,
            create => 1,
            truncate => 1,  # if index already exists with content, trash them before adding more.
        );

        while ( my ( $filename, $hr ) = each %$docs ) {
            my $basename = basename($filename);
            $indexer->add_doc({
                filename    => $basename,
                content     => $hr->{'content'},
                summary     => $hr->{'summary'},
                title       => $hr->{'title'},
            });
        }
        $indexer->commit;
    }#}}}

    sub get_html_width {#{{{
        my $self = shift;
        return ($self->GetClientSize->width - 10);
    }#}}}
    sub get_html_height {#{{{
        my $self = shift;
        return ($self->GetClientSize->height - 40);
    }#}}}
    sub load_html_file {#{{{
        my $self = shift;
        my $file = shift || return;

        ### GetPath does end with a /
        my $fqfn = $self->fs_html->GetPath() . $file;
        unless(-e $fqfn) {
            $self->app->poperr("$fqfn: No such file or directory");
            return;
        }

        $self->htm_window->LoadFile( $self->fs_html->GetPath() . $file );
    }#}}}
    sub make_navbar {#{{{
        my $self = shift;

        my $spacer_width = $self->GetClientSize->width;
        $spacer_width -= $self->nav_img_w * 4;  # left, right, home, search buttons
        $spacer_width -= $self->home_spacer_w;
        $spacer_width -= $self->search_box_w;
        $spacer_width -= 10;                    # right margin

        $spacer_width < 10 and $spacer_width = 10;

        ### AddSpacer is adding unwanted vertical space when it adds the 
        ### wanted horizontal space.  So replace AddSpacer with manual Add 
        ### calls.

        $self->clear_szr_navbar;
        $self->szr_navbar->Add($self->bmp_left, 0, 0, 0);
        $self->szr_navbar->Add($self->bmp_right, 0, 0, 0);
        $self->szr_navbar->Add($self->home_spacer_w, 0, 0);
        $self->szr_navbar->Add($self->bmp_home, 0, 0, 0);
        $self->szr_navbar->Add($spacer_width, 0, 0);
        $self->szr_navbar->Add($self->txt_search, 0, 0, 0);
        $self->szr_navbar->Add($self->bmp_search, 0, 0, 0);

        $self->txt_search->SetFocus;
    }#}}}

    sub OnClose {#{{{
        my $self    = shift;
        my $dialog  = shift;
        my $event   = shift;
        $self->Destroy;
        $event->Skip();
    }#}}}
    sub OnHomeNav {#{{{
        my $self    = shift;    # LacunaWaX::Dialog::Help
        my $dialog  = shift;    # LacunaWaX::Dialog::Help
        my $event   = shift;    # Wx::CommandEvent

        $self->history_idx( $self->history_idx + 1 );
        $self->history->[ $self->history_idx ] = $self->index;
        $self->load_html_file( $self->index );
    }#}}}
    sub OnLeftNav {#{{{
        my $self    = shift;    # LacunaWaX::Dialog::Help
        my $dialog  = shift;    # LacunaWaX::Dialog::Help
        my $event   = shift;    # Wx::CommandEvent

        return if $self->history_idx == 0;

        my $page = $self->history->[ $self->history_idx - 1 ];
        $self->history_idx( $self->history_idx - 1 );
        $self->load_html_file( $page );
    }#}}}
    sub OnLinkClicked {#{{{
        my $self    = shift;    # LacunaWaX::Dialog::Help
        my $dialog  = shift;    # LacunaWaX::Dialog::Help
        my $event   = shift;    # Wx::HtmlLinkEvent

        my $info = $event->GetLinkInfo;

        ### Each link click is triggering this event twice.  This keeps the 
        ### same document from being pushed into our history twice.
        if( $self->prev_click_href eq $info->GetHref ) {
            $event->Skip;
            return;
        }
        $self->prev_click_href( $info->GetHref );

        ### If the user has backed up through their history and then clicked a 
        ### link, we need to diverge to an alternate timeline - truncate the 
        ### history so the current location is the furthest point.
        $#{$self->history} = $self->history_idx;

        push @{$self->history}, $info->GetHref;
        $self->history_idx( $self->history_idx + 1 );
        $event->Skip;
    }#}}}
    sub OnResize {#{{{
        my $self = shift;

        my $old_szr_navbar = $self->szr_navbar;
        $self->make_navbar;
        $self->main_sizer->Replace($old_szr_navbar, $self->szr_navbar);

        ### Layout to force the navbar to update
        ### This must happen before the html window gets resized to avoid ugly 
        ### flashing.
        $self->Layout;

        $self->htm_window->SetSize( Wx::Size->new($self->get_html_width, $self->get_html_height) );
    }#}}}
    sub OnRightNav {#{{{
        my $self    = shift;    # LacunaWaX::Dialog::Help
        my $dialog  = shift;    # LacunaWaX::Dialog::Help
        my $event   = shift;    # Wx::CommandEvent

        return if $self->history_idx == $#{$self->history};

        my $page = $self->history->[ $self->history_idx + 1];
        $self->history_idx( $self->history_idx + 1 );
        $self->load_html_file( $page );
    }#}}}
    sub OnSearchNav {#{{{
        my $self    = shift;    # LacunaWaX::Dialog::Help
        my $dialog  = shift;    # LacunaWaX::Dialog::Help
        my $event   = shift;    # Wx::CommandEvent

        my $term = $self->txt_search->GetValue;
        unless($term) {
            $self->app->popmsg("Searching for nothing isn't going to return many results.");
            return;
        }

        ### Search results do not get recorded in history.

        my $searcher = $self->app->bb->resolve(service => '/Lucy/searcher');
        my $hits = $searcher->hits( query => $term );
        my $vars = {
            term => $term,
        };
        while ( my $hit = $hits->next ) {
            my $hr = {
                content     => $hit->{'content'},
                filename    => $hit->{'filename'},
                summary     => $hit->{'summary'},
                title       => $hit->{'title'},
            };
            push @{$vars->{'hits'}}, $hr;
        }

        my $tmpl_file = 'hitlist.tmpl';
        my $html_file = 'hitlist.html';

        $self->tt->process($tmpl_file, $vars, $html_file);
        $self->load_html_file($html_file);
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;

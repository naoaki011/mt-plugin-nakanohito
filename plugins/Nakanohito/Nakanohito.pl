package MT::Plugin::Nakanohito;

use strict;
use MT;

use LWP::UserAgent;
use HTTP::Request::Common;
use HTTP::Cookies;
use Encode;

use vars qw($VERSION @ISA);#グローバル変数を定義している

@ISA = qw(MT::Plugin);#@ISAはpackage継承するクラスを指定するために使用される
$VERSION = "0.2";

my $plugin = new MT::Plugin::Nakanohito({
	name => 'Nakanohito',
	version => $VERSION,
	description => "<MT_TRANS phrase='login to nakanohito and get footprint and show dashboard widget.'>",
	author_name => "<MT_TRANS phrase='Shinichi Nozawa'>",
	author_link => 'http://nozawashinichi.sakura.ne.jp/fs/',
	doc_link => 'http://www.nozawashinichi.sakura.ne.jp/usingmt/2008/08/mt-widget-nakanohito.html',
	blog_config_template => 'nakanohito_config.tmpl',
    l10n_class => 'Nakanohito::L10N',
	settings => new MT::PluginSettings([
		['nakanohito_id', { Default => undef, Scope => 'blog'}],
		['nakanohito_pw', { Default => undef, Scope => 'blog'}],
		['nakanohito_num', { Default => 10, Scope => 'blog'}],
	]),
});
MT->add_plugin($plugin);



sub init_registry {
    my $plugin = shift;
    $plugin->registry({
        widgets => {
            nakanohito => {
                label    => 'Nakanohito',
                plugin   => $plugin,
                template => 'nakanohito_view.tmpl',
                set => 'sidebar',
                condition => sub { $_[1] =~ /blog:\d+$/; },
                singular => 1,
                handler => \&_widget_handler,
            },
        },
    });
}

sub _widget_handler {
	my $app = shift;
	my ($tmpl, $param) = @_;

	my $blog_id = "blog:".$app->blog->id;

	my $num = $plugin->get_config_value('nakanohito_num', $blog_id) - 1;
	my $id = $plugin->get_config_value('nakanohito_id', $blog_id);
	my $pw = $plugin->get_config_value('nakanohito_pw', $blog_id);

	if(!$id || !$pw){
		$param->{error} = "<MT_TRANS phrase='ID or Password undefined'>";
		return 1; 
	}
	
	#Make an agent and get data
	my $agent = LWP::UserAgent->new;
	my $url = "http://nakanohito.jp/?login";
	my %form = (
		'special'	=> 'special_login',
		'email'		=> $id,
		'passwd'	=> $pw,
	);
	my $req = POST($url, [%form]);
	my $response = $agent->request($req);
	my $cookie_jar = HTTP::Cookies->new;
	$cookie_jar->extract_cookies($response);
	$agent->cookie_jar($cookie_jar);
	my $footprint = "http://nakanohito.jp/stage/my_footprint";
	$response = $agent->request(GET($footprint));
	if(!$response){
		$param->{error} = "<MT_TRANS phrase='Can\'t access to nakanohito. Please check id and pass'>";
		$param->{nakanohito_num} = 0;
		return 1; 
	}
	
	#Form the data 
	my @data = split("table", $response->as_string);
	if(!$data[1]){
		$param->{error} = "<MT_TRANS phrase='There has been no foot print yet.'>";
		$param->{nakanohito_num} = 0;
		return 1; 
	}
	if ( MT->version_number ge '5.0' ) {
		$data[1] = Encode::decode_utf8($data[1]) unless utf8::is_utf8($data[1]);
	}
	$data[1] = "<".$data[1].">";
	my @lines = split("<tr", $data[1]);
	shift @lines;
	shift @lines;
	
	foreach (@lines){
		$_ =~ s/\n//g;
		$_ = "<".$_;
		$_ =~ s/<td .*?>//g;
		$_ =~ s/<\/td>/,/g;
		$_ =~ s/<.*?>//g;
		my @e = split(",", $_);
		$_ = {
			'time' => $e[0],
			'visitor' => $e[1]
		};
	}


	@lines = @lines[0..$num];

	$param->{footprint} = \@lines;
	$param->{nakanohito_num} = ++$num;
}

sub link_nakanohito {
my ($id, $pw) = @_;

my $button = <<EOT;
<form method="post" action="http://nakanohito.jp/?login">
<input type=hidden name=dummy value="UTF-8">
<input type=hidden name=special value="special_login">
<input type=hidden name="email" maxlength="120" value="$id">
<input type=hidden name="passwd" maxlength="30" value="$pw">
<input type="submit" name="Submit" value="go to nakanohito">
</form>
EOT

return $button;
}
1;
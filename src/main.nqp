use Perl6::Grammar;
use Perl6::Actions;
use Perl6::Compiler;

# Determine Perl6 and NQP dirs.
my $sep := nqp::backendconfig()<osname> eq 'MSWin32' ?? '\\' !! '/';
#?if jvm
my $execname := nqp::atkey(nqp::jvmgetproperties,'perl6.execname');
my $exec-dir := nqp::substr($execname, 0, nqp::rindex($execname, $sep));
#?endif
#?if !jvm
my $exec-dir := nqp::substr(nqp::execname(), 0, nqp::rindex(nqp::execname(), $sep));
#?endif


# Initialize Rakudo runtime support.
nqp::p6init();

# Create and configure compiler object.
my $comp := Perl6::Compiler.new();

my $perl6-home := $comp.config<static_perl6_home>
    // nqp::getenvhash()<PERL6_HOME>
    // $exec-dir ~ '/../share/perl6';
if nqp::substr($perl6-home, nqp::chars($perl6-home) - 1) eq $sep {
    $perl6-home := nqp::substr($perl6-home, 0, nqp::chars($perl6-home) - 1);
}

my $nqp-home := $comp.config<static_nqp_home>
    // nqp::getenvhash()<NQP_HOME>
    // $exec-dir ~ '/../share/nqp';
if nqp::substr($nqp-home, nqp::chars($nqp-home) - 1) eq $sep {
    $nqp-home := nqp::substr($nqp-home, 0, nqp::chars($nqp-home) - 1);
}

nqp::bindhllsym('perl6', '$PERL6_HOME', $perl6-home);
nqp::bindhllsym('perl6', '$NQP_HOME', $nqp-home);

$comp.language('perl6');
$comp.parsegrammar(Perl6::Grammar);
$comp.parseactions(Perl6::Actions);
$comp.addstage('syntaxcheck', :before<ast>);
$comp.addstage('optimize', :after<ast>);
hll-config($comp.config);
nqp::bindhllsym('perl6', '$COMPILER_CONFIG', $comp.config);

# Add extra command line options.
my @clo := $comp.commandline_options();
@clo.push('parsetrace');
@clo.push('setting=s');
@clo.push('n');
@clo.push('p');
@clo.push('doc=s?');
@clo.push('optimize=s?');
@clo.push('c');
@clo.push('I=s');
@clo.push('M=s');
@clo.push('nqp-lib=s');

#?if js
@clo.push('beautify');
#?endif

# Set up END block list, which we'll run at exit.
nqp::bindhllsym('perl6', '@END_PHASERS', []);

# In an embedding environment, let @*ARGS be empty instead of crashing
nqp::bindhllsym('perl6', '$!ARGITER', 0);

#?if jvm
sub MAIN(*@ARGS) {
#?endif
#?if moar
sub MAIN(@ARGS) {
#?endif
#?if js
sub MAIN(*@ARGS) {
#?endif
    # Enter the compiler.
    $comp.command_line(@ARGS, :encoding('utf8'), :transcode('ascii iso-8859-1'));

    # do all the necessary actions at the end, if any
    if nqp::gethllsym('perl6', '&THE_END') -> $THE_END {
        $THE_END()
    }
}

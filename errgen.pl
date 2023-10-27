open(EKIPPC, '<'. "ekipp.c");
open(ERRHEAD, '>', "errors.gen");

my $ecode = 80;
my %registery;


for (<EKIPPC>) {
	m/EEXIT\(ERR_([A-Z\_]+), ECODE_([A-Z\_]+)\)/;
	next if ($registery{$1});
	print ERRHEAD "#define ERR_", $1, " ", qw/"/, "Error occured. Code: ", $1, qw/"/, "\n";
	print ERRHEAD "#define ECODE_", $2, " ", $ecode++, "\n\n";
	$registery{$1} = 1;
}

close(EKIPPC);
close(ERRHEAD);

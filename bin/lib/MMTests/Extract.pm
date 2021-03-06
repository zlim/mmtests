# Extract.pm
#
# This is base class description for modules that parse MM Tests directories
# and extract information from them

package MMTests::Extract;

use constant DATA_CPUTIME		=> 1;
use constant DATA_WALLTIME		=> 2;
use constant DATA_WALLTIME_VARIABLE	=> 3;
use constant DATA_OPSSEC		=> 4;
use constant DATA_THROUGHPUT		=> 5;
use VMR::Stat;
use MMTests::PrintGeneric;
use MMTests::PrintHtml;
use strict;

sub new() {
	my $class = shift;
	my $self = {
		_ModuleName 	=> "Extract",
		_DataType	=> 0,
		_FieldHeaders	=> [],
		_FieldLength	=> 0,
		_Headers	=> [ "Base" ],
	};
	bless $self, $class;
	return $self;
}

sub getModuleName() {
	my ($self) = @_;
	return $self->{_ModuleName};
}

sub initialise() {
	my ($self, $reportDir, $testName, $format) = @_;
	my (@fieldHeaders, @plotHeaders, @summaryHeaders);
	my ($fieldLength, $plotLength, $summaryLength);

	if ($self->{_DataType} == DATA_CPUTIME) {
		$fieldLength = 12;
		$summaryLength = 12;
		$plotLength = 12;
		@fieldHeaders = ("User", "System", "Elapsed", "CPU");
		@summaryHeaders = ("Operation", "User", "System", "Elapsed", "CPU");
		@plotHeaders = ("LowStddev", "Min", "Max", "HighStddev", "Mean");
	} elsif ($self->{_DataType} == DATA_WALLTIME) {
		$fieldLength = 12;
		$summaryLength = 12;
		$plotLength = 12;
		@fieldHeaders = ("Unit", "WallTime");
		@summaryHeaders = ("Time", "Unit");
		@plotHeaders = ("Unit", "WallTime");
	} elsif ($self->{_DataType} == DATA_OPSSEC ||
		 $self->{_DataType} == DATA_WALLTIME_VARIABLE) {
		$fieldLength = 12;
		$plotLength = 12;
		$summaryLength = 12;
		@fieldHeaders = ("Unit", "Ops/sec");
		@plotHeaders = ("Unit", "Ops/sec");
		@summaryHeaders = ("Unit", "Min", "Mean", "TrueMean", "Stddev", "Max");
	} elsif ($self->{_DataType} == DATA_THROUGHPUT) {
		$fieldLength = 12;
		$plotLength = 12;
		$summaryLength = 12;
		@fieldHeaders = ("Unit", "Throughput");
		@plotHeaders = ("Unit", "Throughput");
		@summaryHeaders = ("Min", "Mean", "TrueMean", "Stddev", "Max");
	} else {
		$fieldLength = 18;
		@fieldHeaders = ("UnknownType");
	}

	$self->{_TestName} = $testName;
	$self->{_FieldLength}  = $fieldLength;
	$self->{_FieldHeaders} = \@fieldHeaders;
	$self->{_PlotLength} = $plotLength;
	$self->{_PlotHeaders} = \@plotHeaders;
	$self->{_SummaryLength}  = $summaryLength;
	$self->{_SummaryHeaders} = \@summaryHeaders;
}

sub setFormat() {
	my ($self, $format) = @_;
	if ($format eq "html") {
		$self->{_PrintHandler} = MMTests::PrintHtml->new();
	} else {
		$self->{_PrintHandler} = MMTests::PrintGeneric->new();
	}
}

sub printDataType() {
	my ($self) = @_;
	if ($self->{_DataType} == DATA_CPUTIME) {
		print "CPUTime";
	} elsif ($self->{_DataType} == DATA_WALLTIME) {
		print "WallTime";
	} elsif ($self->{_DataType} == DATA_WALLTIME_VARIABLE) {
		print "WallTimeVariable";
	} elsif ($self->{_DataType} == DATA_THROUGHPUT) {
		print "Throughput";
	} elsif ($self->{_DataType} == DATA_OPSSEC) {
		print "Operations/sec";
	} else {
		print "Unknown";
	}
}

sub printExtraHeaders() {
	my ($self) = @_;
	if (!defined $self->{_ExtraLength}) {
		return;
	}
	$self->{_PrintHandler}->printHeaders(
		$self->{_ExtraLength}, $self->{_ExtraHeaders},
		$self->{_FieldHeaderFormat});
}

sub printReportTop() {
	my ($self) = @_;
	$self->{_PrintHandler}->printTop();
}

sub printReportBottom() {
	my ($self) = @_;
	$self->{_PrintHandler}->printBottom();
}

sub printFieldHeaders() {
	my ($self) = @_;
	$self->{_PrintHandler}->printHeaders(
		$self->{_FieldLength}, $self->{_FieldHeaders},
		$self->{_FieldHeaderFormat});
}

sub printPlotHeaders() {
	my ($self) = @_;
	$self->{_PrintHandler}->printHeaders(
		$self->{_PlotLength}, $self->{_PlotHeaders},
		$self->{_FieldHeaderFormat});
}

sub setSummaryLength() {
	my ($self, $subHeading);

	$self->{_SummaryLength} = $self->{_FieldLength};
}

sub printSummaryHeaders() {
	my ($self) = @_;
	if (defined $self->{_SummaryLength}) {
		$self->{_PrintHandler}->printHeaders(
			$self->{_SummaryLength}, $self->{_SummaryHeaders},
			$self->{_FieldHeaderFormat});
	} else {
		$self->printFieldHeaders();
	}
}

sub _printCandlePlotData() {
	my ($self, $fieldLength, @data) = @_;

	my $stddev = calc_stddev(@data);
	my $mean = calc_mean(@data);
	my $min  = calc_min(@data);
	my $max  = calc_max(@data);
	my $low_stddev = calc_max( ($mean - $stddev, $min) );
	my $high_stddev = calc_min( ($mean + $stddev, $max) );

	printf("%${fieldLength}.3f %${fieldLength}.3f %${fieldLength}.3f %${fieldLength}.3f %${fieldLength}.3f	# stddev=%-${fieldLength}.3f\n", $low_stddev, $min, $max, $high_stddev, $mean, $stddev);
}

sub _printCandlePlot() {
	my ($self, $fieldLength, $column) = @_;
	my @data;

	# Extract the data
	foreach my $row (@{$self->{_ResultData}}) {
		my @rowArray = @{$row};
		push @data, $rowArray[$column];
	}

	$self->_printCandlePlotData($fieldLength, @data);
}

sub printPlot() {
	my ($self, $subheading) = @_;
	my $fieldLength = $self->{_PlotLength};

	if ($self->{_DataType} == DATA_CPUTIME) {
		my $column;

		# Figure out which column we need
		if ($subheading eq "User") {
			$column = 0;
		} elsif ($subheading eq "System") {
			$column = 1;
		} elsif ($subheading eq "Elapsed") {
			$column = 2;
		} elsif ($subheading eq "CPU") {
			$column = 3;
		} else {
			print("Unknown sub-heading '$subheading', specify --sub-heading\n");
			return;
		}
		$self->_printCandlePlot($fieldLength - 1, $column);
	} elsif ($self->{_DataType} == DATA_WALLTIME) {
		$self->printSummary();
	} elsif ($self->{_DataType} == DATA_OPSSEC) {
		my $column = 0;
		$column = $self->{_SummariseColumn} if defined $self->{_SummariseColumn};
		$self->_printCandlePlot($fieldLength, $column);
	} elsif ($self->{_DataType} == DATA_THROUGHPUT) {
		my $column = 0;
		$column = $self->{_SummariseColumn} if defined $self->{_SummariseColumn};
		$self->_printCandlePlot($fieldLength, $column);
	} else {
		print "Unhandled data type for plotting.\n";
	}
}

sub extractSummary() {
	my ($self, $subHeading) = @_;
	my @formatList;
	my $fieldLength = $self->{_FieldLength};
	if (defined $self->{_FieldFormat}) {
		@formatList = @{$self->{_FieldFormat}};
	}

	if ($self->{_DataType} == DATA_CPUTIME) {
		my (@user, @sys, @elapsed, @cpu);

		foreach my $row (@{$self->{_ResultData}}) {
			my @rowArray = @{$row};
			push @user,    $rowArray[0];
			push @sys,     $rowArray[1];
			push @elapsed, $rowArray[2];
			push @cpu,     $rowArray[3];
		}

		$self->{_FieldFormat} = [ "%-${fieldLength}s" ];
		foreach my $funcName ("calc_min", "calc_mean", "calc_stddev", "calc_max") {
			no strict "refs";
			my $op = $funcName;
			$op =~ s/calc_//;

			push @{$self->{_SummaryData}}, [$op,
							&$funcName(@user),
							&$funcName(@sys),
							&$funcName(@elapsed),
							&$funcName(@cpu) ];
		}
	} elsif ($self->{_DataType} == DATA_WALLTIME_VARIABLE) {
		my (%units, @walltimes);
		@walltimes = [];
		my @row;
		foreach my $row (@{$self->{_ResultData}}) {
			my @rowArray = @{$row};
			$units{$rowArray[0]} = 1;
			push @{$walltimes[$rowArray[0]]}, $rowArray[1];
		}

		push @row, "Ops";
		foreach my $unit (sort {$a <=> $b} (keys %units)) {
			foreach my $funcName ("calc_min", "calc_mean", "calc_true_mean", "calc_stddev", "calc_max") {
				no strict "refs";
				push @row, &$funcName(@{$walltimes[$unit]});
			}
		}
		push @{$self->{_SummaryData}}, \@row;
	} elsif ($self->{_DataType} == DATA_WALLTIME) {
		my (%units, @walltimes);
		@walltimes = [];
		foreach my $row (@{$self->{_ResultData}}) {
			my @rowArray = @{$row};
			$units{$rowArray[0]} = 1;
			push @{$walltimes[$rowArray[0]]}, $rowArray[1];
		}

		foreach my $unit (sort {$a <=> $b} (keys %units)) {
			my $mean;
			if ($self->{_UseTrueMean} == 1) {
				$mean = calc_true_mean(99, 1, @{$walltimes[$unit]});
			} else {
				$mean = calc_mean(@{$walltimes[$unit]});
			}
			push @{$self->{_SummaryData}}, [$unit, $mean];
		}
	} elsif ($self->{_DataType} == DATA_OPSSEC) {
		my @ops;
		my @row;
		my $column = 0;
		$column = $self->{_SummariseColumn} if defined $self->{_SummariseColumn};

		foreach my $row (@{$self->{_ResultData}}) {
			push @ops, @{$row}[$column];
		}
		push @row, $subHeading;
		foreach my $funcName ("calc_min", "calc_mean", "calc_true_mean", "calc_stddev", "calc_max") {
			no strict "refs";
			push @row, &$funcName(@ops)
		}
		push @{$self->{_SummaryData}}, \@row;
	} else {
		print "Unknown data type for summarising\n";
	}

	return 1;
}

sub printSummary() {
	my ($self, $subHeading) = @_;
	my @formatList;
	my $fieldLength = $self->{_FieldLength};
	if (defined $self->{_FieldFormat}) {
		@formatList = @{$self->{_FieldFormat}};
	}

	$self->extractSummary($subHeading);
	$self->{_PrintHandler}->printRow($self->{_SummaryData}, $fieldLength, $self->{_FieldFormat});
}

sub _printClientReport() {
	my ($self, $reportDir, @clients) = @_;
	my @data = @{$self->{_ResultData}};

	my $fieldLength = $self->{_FieldLength};
	foreach my $client (@clients) {
		$self->{_PrintHandler}->printRow($data[$client], $fieldLength, $self->{_FieldFormat}, "%-${fieldLength}d", $client);
	}
}

sub _printClientExtra() {
	my ($self, $reportDir, @clients) = @_;
	my @data = @{$self->{_ExtraData}};

	my $fieldLength = $self->{_ExtraLength};
	foreach my $client (@clients) {
		$self->{_PrintHandler}->printRow($data[$client], $fieldLength, $self->{_ExtraFormat}, "%-${fieldLength}d", $client);
	}
}

sub printExtra() {
	my ($self) = @_;
	my @formatList;
	if (!defined $self->{_ExtraData}) {
		return;
	}

	$self->{_PrintHandler}->printRow($self->{_ExtraData}, $self->{_ExtraLength}, $self->{_ExtraFormat});
}

sub printReport() {
	my ($self) = @_;
	if ($self->{_DataType} == DATA_CPUTIME ||
			$self->{_DataType} == DATA_WALLTIME ||
			$self->{_DataType} == DATA_OPSSEC ||
			$self->{_DataType} == DATA_THROUGHPUT) {
		$self->{_PrintHandler}->printRow($self->{_ResultData}, $self->{_FieldLength}, $self->{_FieldFormat});
	} else {
		print "Unknown data type for reporting raw data\n";
	}
}

1;

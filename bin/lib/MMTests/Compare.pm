# Compare.pm
#
# This is base class description for modules that take summaries from
# the Extract classes and compare them with each other.

package MMTests::Compare;

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
		_ModuleName 	=> "Compare",
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
	my ($self, $extractModulesRef) = @_;
	my (@fieldHeaders, @plotHeaders, @summaryHeaders);
	my ($fieldLength, $plotLength, $summaryLength);
	my $compareLength = 6;

	if ($self->{_DataType} == DATA_CPUTIME) {
		$fieldLength = 12;
		$compareLength = 6;
		@fieldHeaders = ("User", "System", "Elapsed", "CPU");
	} elsif ($self->{_DataType} == DATA_WALLTIME) {
		$fieldLength = 12;
		$compareLength = 6;
		@fieldHeaders = ("Time", "Procs");
	}

	if (!$self->{_FieldLength}) {
		$self->{_FieldLength}  = $fieldLength;
	}
	if (!$self->{_CompareLength}) {
		$self->{_CompareLength}  = $compareLength;
	}
	$self->{_FieldHeaders} = \@fieldHeaders;
	$self->{_ExtractModules} = $extractModulesRef;
}

sub setFormat() {
	my ($self, $format) = @_;

	if ($format eq "html") {
		$self->{_PrintHandler} = MMTests::PrintHtml->new(1);
	} else {
		$self->{_PrintHandler} = MMTests::PrintGeneric->new(1);
	}
}

sub printReportTop($) {
	my ($self) = @_;
	$self->{_PrintHandler}->printTop();
}

sub printReportBottom($) {
	my ($self) = @_;
	$self->{_PrintHandler}->printBottom();
}

sub printFieldHeaders() {
	my ($self) = @_;
	$self->{_PrintHandler}->printHeaders(
		$self->{_FieldLength}, $self->{_FieldHeaders},
		$self->{_FieldHeaderFormat});
}

sub _generateTitleTable() {
	my ($self) = @_;
	my @titleTable;

	my @extractModules = @{$self->{_ExtractModules}};
	my @summaryHeaders = @{$extractModules[0]->{_SummaryHeaders}};
	my $baselineRef = $extractModules[0]->{_SummaryData};
	my @baseline = @{$baselineRef};

	for (my $column = 1; $column <= $#summaryHeaders; $column++) {
		for (my $row = 0; $row <= $#baseline; $row++) {
			push @titleTable, [$summaryHeaders[$column],
				   	$baseline[$row][0]];
		}
	}

	$self->{_TitleTable} = \@titleTable;
}

sub _generateComparisonTable() {
	my ($self, $subHeading, $showCompare) = @_;
	my @resultsTable;
	my @compareTable;

	my @extractModules = @{$self->{_ExtractModules}};
	my @summaryHeaders = @{$extractModules[0]->{_SummaryHeaders}};
	my $baselineRef = $extractModules[0]->{_SummaryData};
	my @baseline = @{$baselineRef};

	for (my $column = 1; $column <= $#summaryHeaders; $column++) {
		for (my $row = 0; $row <= $#baseline; $row++) {
			my @data;
			my @compare;
			my $compareOp = "pdiff";
			if (defined $self->{_CompareOp}) {
				$compareOp = $self->{_CompareOp};
			}
			if (defined $self->{_CompareOps}) {
				$compareOp = $self->{_CompareOps}[$column];
			}
			for (my $module = 0; $module <= $#extractModules; $module++) {
				no strict "refs";
				my $summaryRef = $extractModules[$module]->{_SummaryData};
				my @summary = @{$summaryRef};
				if ($subHeading eq "ratio") {
					push @data, rdiff($summary[$row][$column], $baseline[$row][$column]);
				} else {
					push @data, $summary[$row][$column];
					push @compare, &$compareOp($summary[$row][$column], $baseline[$row][$column]);
				}
			}
			push @resultsTable, [@data];
			push @compareTable, [@compare];
		}
	}

	$self->{_ResultsTable} = \@resultsTable;

	if ($showCompare) {
		$self->{_CompareTable} = \@compareTable;
	}
}

sub _generateHeaderTable() {
	my ($self) = @_;
	my @headerTable;
	my @headerFormat;

	my @extractModules = @{$self->{_ExtractModules}};
	my $operationLength = $self->{_OperationLength};
	push @headerFormat, "%${operationLength}s";

	# Headers
	for (my $i = 0; $i <= 1; $i++) {
		my @row;
		push @row, "";
		for (my $j = 0; $j <= $#extractModules; $j++) {
			my $testName = $extractModules[$j]->{_TestName};
			my $index = index($testName, "-");

			# Bodge identification of -rc. Will fail if there is
			# every an -rc10 and will screw up if the name just
			# happened to have -rc at the start
			if (substr($testName, $index, $index+3) =~ /-rc[0-9]/) {
				$index += 4;
			}

			my $element;
			if ($i == 0) {
				my $len = $extractModules[$j]->{_FieldLength};
				if (defined $self->{_CompareTable}) {
					$len += $self->{_CompareLength} + 4;
				}
				$element = substr($testName, 0, $index);
				push @headerFormat, "%${len}s";
			} else {
				$element = substr($testName, $index + 1);
			}
			push @row, $element;
		}
		push @headerTable, [@row];
	}
	$self->{_HeaderTable} = \@headerTable;
	$self->{_HeaderFormat} = \@headerFormat;
}

# Construct final table for printing
sub _generateRenderTable() {
	my ($self, $rowOrientated) = @_;
	my @finalTable;
	my @formatTable;
	my @compareTable;

	my @titleTable = @{$self->{_TitleTable}};
	my @resultsTable = @{$self->{_ResultsTable}};
	my $fieldLength = $self->{_FieldLength};
	my $compareLength = 0;
	my $precision = 2;
	if ($self->{_Precision}) {
		$precision = $self->{_Precision};
	}
	my @compareTable;
	if (defined $self->{_CompareTable}) {
		@compareTable = @{$self->{_CompareTable}};
		$compareLength = $self->{_CompareLength};
	}

	my @extractModules = @{$self->{_ExtractModules}};
	my @summaryHeaders = @{$extractModules[0]->{_SummaryHeaders}};
	my $baselineRef = $extractModules[0]->{_SummaryData};
	my @baseline = @{$baselineRef};

	# Format string for columns
	my $maxLength = 0;
	for (my $column = 1; $column <= $#summaryHeaders; $column++) {
		my $len = length($summaryHeaders[$column]);
		if ($len > $maxLength) {
			$maxLength = $len;
		}
	}
	push @formatTable, "%-${maxLength}s";
	$self->{_OperationLength} = $maxLength;

	# Format string for source table rows
	if (!$rowOrientated) {
		$maxLength = 0;
		for (my $row = 0; $row <= $#baseline; $row++) {
			my $length = length($baseline[$row][0]);
			if ($length > $maxLength) {
				$maxLength = $length;
			}
		}
		push @formatTable, " %-${maxLength}s";
		$self->{_OperationLength} += $maxLength + 1;
	} else {
		push @formatTable, "";
	}

	# Build column format table
	for (my $i = 0; $i <= $#{$resultsTable[0]}; $i++) {
		my $fieldFormat = "ROW";
		if (!$rowOrientated) {
			$fieldFormat = "%${fieldLength}.${precision}f"
		}
		if (defined $self->{_CompareTable}) {
			push @formatTable, ($fieldFormat, " (%${compareLength}.2f%%)");
		} else {
			push @formatTable, $fieldFormat;
		}
	}

	# Final comparison table
	for (my $row = 0; $row <= $#titleTable; $row++) {
		my @row;
		foreach my $elements ($titleTable[$row]) {
			foreach my $element (@{$elements}) {
				push @row, $element;
			}
		}
		for (my $i = 0; $i <= $#{$resultsTable[$row]}; $i++) {
			push @row, $resultsTable[$row][$i];
			if (defined $self->{_CompareTable}) {
				push @row, $compareTable[$row][$i];
			}
		}
		push @finalTable, [@row];
	}

	$self->{_RenderTable} = \@finalTable;
	$self->{_FieldFormat} = \@formatTable;
}

sub extractComparison() {
	my ($self, $subHeading, $showCompare) = @_;

	$self->_generateTitleTable();
	$self->_generateComparisonTable($subHeading, $showCompare);
}

sub _printComparisonRow() {
	my ($self) = @_;
	my @extractModules = @{$self->{_ExtractModules}};

	$self->_generateRenderTable(1);
	$self->_generateHeaderTable();

	$self->{_PrintHandler}->printHeaderRow($self->{_HeaderTable},
		$self->{_FieldLength},
		$self->{_HeaderFormat});
	$self->{_PrintHandler}->printRow($self->{_RenderTable},
		$self->{_FieldLength},
		$self->{_FieldFormat},
		$extractModules[0]->{_RowFieldFormat});
}

sub printComparison() {
	my ($self) = @_;
	my @extractModules = @{$self->{_ExtractModules}};

	if ($extractModules[0]->{_RowOrientated}) {
		return $self->_printComparisonRow();
	}

	$self->_generateRenderTable(0);
	$self->_generateHeaderTable();

	$self->{_PrintHandler}->printTop();
	$self->{_PrintHandler}->printHeaderRow($self->{_HeaderTable},
		$self->{_FieldLength},
		$self->{_HeaderFormat});
	$self->{_PrintHandler}->printRow($self->{_RenderTable},
		$self->{_FieldLength},
		$self->{_FieldFormat});
	$self->{_PrintHandler}->printBottom();
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

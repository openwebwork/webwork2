#!/usr/math/bin/perl -w


# This is the "exported" subroutine.  Use this to evaluate the units given in an answer.

sub evaluate_units {
	&Units::evaluate_units;
}

# Methods for evaluating units in answers
package Units;

#require Exporter;
#@ISA = qw(Exporter);
#@EXPORT = qw(evaluate_units);


# compound units are entered such as m/sec^2 or kg*m/sec^2
# the format is unit[^power]*unit^[*power].../  unit^power*unit^power....
# there can be only one / in a unit.
# powers can be negative integers as well as positive integers.

    # These subroutines return a unit hash.
    # A unit hash has the entries
    #      factor => number   number can be any real number
    #      m      => power    power is a signed integer
    #      kg     => power
    #      s      => power
    #      rad    => power
    #      degC   => power
    #      degF   => power
    #      degK   => power
    #      perhaps other fundamental units will added later as well.


my %fundamental_units = ('factor' => 1,
                     'm'      => 0,
                     'kg'     => 0,
                     's'      => 0,
                     'rad'    => 0,
                     'degC'   => 0,
                     'degF'   => 0,
                     'degK'   => 0,
                     'mol'    => 0,  # moles, treated as a fundamental unit?
);

# This hash contains all of the units which will be accepted.  These must
#be defined in terms of the
# fundamental units given above.  If the power of the fundamental unit is
#not included it is assumed to
# be zero.

my $PI = 4*atan2(1,1);

my %known_units = ('m'  => {
                           'factor'    => 1,
                           'm'         => 1
                          },
                 'kg'  => {
                           'factor'    => 1,
                           'kg'        => 1
                          },
                 's'  => {
                           'factor'    => 1,
                           's'         => 1
                          },
                'rad' => {
                           'factor'    => 1,
                           'rad'       => 1
                          },
               'degC' => {
                           'factor'    => 1,
                           'degC'      => 1
                          },
               'degF' => {
                           'factor'    => 1,
                           'degF'      => 1
                          },
               'degK' => {
                           'factor'    => 1,
                           'degK'      => 1
                          },
               'mol'  => {
               				'factor'	=>1,
               				'mol'		=>1
               			  },
# ANGLES
# deg  -- degrees
#
                'deg'  => {
                           'factor'    => 0.0174532925,
                           'rad'       => 1
                          },
# TIME
# s     -- seconds
# ms    -- miliseconds
# min   -- minutes
# hr    -- hours
# day   -- days
# yr    -- years  -- 365 days in a year
#
                  'ms'  => {
                           'factor'    => 0.001,
                           's'         => 1
                          },
                  'min'  => {
                           'factor'    => 60,
                           's'         => 1
                          },
                  'hr'  => {
                           'factor'    => 3600,
                           's'         => 1
                          },
                  'day'  => {
                           'factor'    => 86400,
                           's'         => 1
                          },
                  'yr'  => {
                           'factor'    => 31557600,
                           's'         => 1
                          },

# LENGTHS
# m    -- meters
# cm   -- centimeters
# km   -- kilometers
# mm   -- millimeters
# micron -- micrometer
# um   -- micrometer
# nm   -- nanometer
# A    -- Angstrom
#
                 'km'  => {
                           'factor'    => 1000,
                           'm'         => 1
                          },
                 'cm'  => {
                           'factor'    => 0.01,
                           'm'         => 1
                          },
                 'mm'  => {
                           'factor'    => 0.001,
                           'm'         => 1
                          },
             'micron'  => {
                           'factor'    => 10**(-6),
                           'm'         => 1
                          },
                 'um'  => {
                           'factor'    => 10**(-6),
                           'm'         => 1
                          },
                 'nm'  => {
                           'factor'    => 10**(-9),
                           'm'         => 1
                          },
                  'A'  => {
                           'factor'    => 10**(-10),
                           'm'         => 1
                          },
# ENGLISH LENGTHS
# in    -- inch
# ft    -- feet
# mi    -- mile
# light-year
#
                 'in'  => {
                           'factor'    => 0.0254,
                           'm'         => 1
                          },
                 'ft'  => {
                           'factor'    => 0.3048,
                           'm'         => 1
                          },
                 'mi'  => {
                           'factor'    => 1609.344,
                           'm'         => 1
                          },
         'light-year'  => {
                           'factor'    => 9.46E15,
                           'm'         => 1
                          },
# VOLUME
# L   -- liter
# ml -- milliliters
# cc -- cubic centermeters
#
                  'L'  => {
                           'factor'    => 0.001,
                           'm'         => 3
                          },
                 'cc'  => {
                           'factor'    => 10**(-6),
                           'm'         => 3,
                          },
                 'ml'  => {
                           'factor'    => 10**(-6),
                           'm'         => 3,
                          },
# VELOCITY
# knots -- nautical miles per hour
#
              'knots'  => {
                           'factor'    =>  0.5144444444,
                           'm'         => 1,
                           's'         => -1
                          },
# MASS
# g    -- grams
# kg   -- kilograms
#
                  'g'  => {
                           'factor'    => 0.001,
                           'kg'         => 1
                          },
# ENGLISH MASS
# slug -- slug
#
               'slug'  => {
                           'factor'    => 14.6,
                           'kg'         => 1
                          },
# FREQUENCY
# Hz    -- Hertz
# kHz   -- kilo Hertz
# MHz   -- mega Herta
#
                 'Hz'  => {
                           'factor'    => 2*$PI,  #2pi
                           's'         => -1,
                           'rad'       => 1
                          },
                'kHz'  => {
                           'factor'    => 1000*2*$PI,  #1000*2pi,
                           's'         => -1,
                           'rad'       => 1
                          },
                'MHz'  => {
                           'factor'    => (10**6)*2*$PI,  #10^6 * 2pi,
                           's'         => -1,
                           'rad'       => 1
                          },
                'rev'  => {
                			'factor'   => 2*$PI, 
                			'rad'      => 1
                		  },
                'cycles'  => {
                			'factor'   => 2*$PI, 
                			'rad'      => 1
                		  },                       

# COMPOUND UNITS
#
# FORCE
# N      -- Newton
# microN -- micro Newton
# uN     -- micro Newton
# dyne   -- dyne
# lb     -- pound
# ton    -- ton
#
                 'N'  => {
                           'factor'    => 1,
                           'm'         => 1,
                           'kg'        => 1,
                           's'         => -2
                          },
            'microN'  => {
                           'factor'    => 10**(-6),
                           'm'         => 1,
                           'kg'        => 1,
                           's'         => -2
                          },
                 'uN'  => {
                           'factor'    => 10**(-6),
                           'm'         => 1,
                           'kg'        => 1,
                           's'         => -2
                          },
               'dyne'  => {
                           'factor'    => 10**(-5),
                           'm'         => 1,
                           'kg'        => 1,
                           's'         => -2
                          },
                 'lb'  => {
                           'factor'    => 4.45,
                           'm'         => 1,
                           'kg'        => 1,
                           's'         => -2
                          },
                'ton'  => {
                           'factor'    => 8900,
                           'm'         => 1,
                           'kg'        => 1,
                           's'         => -2
                          },
# ENERGY
# J      -- Joule
# kJ     -- kilo Joule
# erg    -- erg
# lbf    -- foot pound
# cal    -- calorie
# kcal   -- kilocalorie
# eV     -- electron volt
# kWh    -- kilo Watt hour
#
                    'J'  => {
                           'factor'    => 1,
                           'm'         => 2,
                           'kg'        => 1,
                           's'         => -2
                          },
                 'kJ'  => {
                           'factor'    => 1000,
                           'm'         => 2,
                           'kg'        => 1,
                           's'         => -2
                          },
                'erg'  => {
                           'factor'    => 10**(-7),
                           'm'         => 2,
                           'kg'        => 1,
                           's'         => -2
                          },
                'lbf'  => {
                           'factor'    => 1.355,
                           'm'         => 2,
                           'kg'        => 1,
                           's'         => -2
                          },
                'cal'  => {
                           'factor'    => 4.19,
                           'm'         => 2,
                           'kg'        => 1,
                           's'         => -2
                          },
               'kcal'  => {
                           'factor'    => 4190,
                           'm'         => 2,
                           'kg'        => 1,
                           's'         => -2
                          },
                'eV'  => {
                           'factor'    => 1.60E-9,
                           'm'         => 2,
                           'kg'        => 1,
                           's'         => -2
                          },
                'kWh'  => {
                           'factor'    => 3.6E6,
                           'm'         => 2,
                           'kg'        => 1,
                           's'         => -2
                          },
# POWER
# W      -- Watt
# kW     -- kilo Watt
# hp     -- horse power  746 W
#
                 'W'  => {
                           'factor'    => 1,
                           'm'         => 2,
                           'kg'        => 1,
                           's'         => -3
                          },
                 'kW'  => {
                           'factor'    => 1000,
                           'm'         => 2,
                           'kg'        => 1,
                           's'         => -3
                          },
                'hp'   => {
                           'factor'    => 746,
                           'm'         => 2,
                           'kg'        => 1,
                           's'         => -3
                          },
# PRESSURE
# Pa     -- Pascal
# kPa    -- kilo Pascal
# atm    -- atmosphere
                 'Pa'  => {
                           'factor'    => 1,
                           'm'         => -1,
                           'kg'        => 1,
                           's'         => -2
                          },
                'kPa'  => {
                           'factor'    => 1000,
                           'm'         => -1,
                           'kg'        => 1,
                           's'         => -2
                          },
                'atm'  => {
                           'factor'    => 1.01E5,
                           'm'         => -1,
                           'kg'        => 1,
                           's'         => -2
                          },

);



sub process_unit {
	
	my $string = shift; 
    die ("UNIT ERROR: No units were defined.") unless defined($string);  #   
	#split the string into numerator and denominator --- the separator is /
    my ($numerator,$denominator) = split( m{/}, $string );

	
	
	$denominator = "" unless defined($denominator);
	my %numerator_hash = process_term($numerator);
	my %denominator_hash =  process_term($denominator);


    my %unit_hash = %fundamental_units;
	my $u;
	foreach $u (keys %unit_hash) {
		if ( $u eq 'factor' ) {
			$unit_hash{$u} = $numerator_hash{$u}/$denominator_hash{$u};  # calculate the correction factor for the unit
		} else {
			
			$unit_hash{$u} = $numerator_hash{$u} - $denominator_hash{$u}; # calculate the power of the fundamental unit in the unit
		}
	}	
	# return a unit hash.  
	return(%unit_hash);
}

sub process_term {
	my $string = shift;  
	my %unit_hash = %fundamental_units;
	if ($string) {
		
		#split the numerator or denominator into factors -- the separators are *
		
	    my @factors = split(/\*/, $string);
		
		my $f;
		foreach $f (@factors) {
			my %factor_hash = process_factor($f);
			
			my $u;
			foreach $u (keys %unit_hash) {
				if ( $u eq 'factor' ) {
					$unit_hash{$u} = $unit_hash{$u} * $factor_hash{$u};  # calculate the correction factor for the unit
				} else {
					
					$unit_hash{$u} = $unit_hash{$u} + $factor_hash{$u}; # calculate the power of the fundamental unit in the unit
				}
			}
		}
	}
	#returns a unit hash.
	#print "process_term returns", %unit_hash, "\n";
	return(%unit_hash);
}	
	

sub process_factor {
	my $string = shift;  
	#split the factor into unit and powers
	
    my ($unit_name,$power) = split(/\^/, $string);
	$power = 1 unless defined($power);
	my %unit_hash = %fundamental_units;
	
	if ( defined( $known_units{$unit_name} )  ) {
		my %unit_name_hash = %{$known_units{$unit_name}};   # $reference_units contains all of the known units.
		my $u;
		foreach $u (keys %unit_hash) {
			if ( $u eq 'factor' ) {
				$unit_hash{$u} = $unit_name_hash{$u}**$power;  # calculate the correction factor for the unit
			} else {
				my $fundamental_unit = $unit_name_hash{$u};
				$fundamental_unit = 0 unless defined($fundamental_unit); # a fundamental unit which doesn't appear in the unit need not be defined explicitly
				$unit_hash{$u} = $fundamental_unit*$power; # calculate the power of the fundamental unit in the unit
			}
		}
	} else {
		die "UNIT ERROR Unrecognizable unit: |$unit_name|";
	}
	%unit_hash;
}

# This is the "exported" subroutine.  Use this to evaluate the units given in an answer.
sub evaluate_units {
	my $unit = shift;
	my %output =  eval(q{process_unit( $unit)});
	%output = %fundamental_units if $@;  # this is what you get if there is an error.
	$output{'ERROR'}=$@ if $@;
	%output;
}
#################

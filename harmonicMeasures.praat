#################################
### DEPRECATED 1 FEB 2017
### SEE voicesauceMeasures.praat
#################################

## harmonicMeasures.praat
## version 0.0.1
## by James Kirby
## <j.kirby@ed.ac.uk>
## based on code by Timothy Mills, Chad Vicenik, Patrick Callier and the VoiceSauce codebase 
#
# This script is designed to measure spectral tilt following the technique 
# described by Iseli et al. (2007):
#
# Iseli, M., Y.-L Shue, and A. Alwan.  2007.  Age, sex, and vowel 
#   dependencies of acoustic measures related to the voice source.
#	Journal of the Acoustical Society of America 121(4): 2283-2295.
#
# This method aims to correct the magnitudes of the spectral harmonics
# by compensating for the influence of formant frequencies on the 
# spectral magnitude estimation. From the article (p.2285):
#
# "The purpose of this correction formula is to “undo” the effects of
# the formants on the magnitudes of the source spectrum. This is done 
# by subtracting the amount by which the formants boost the spectral 
# magnitudes. For example, the corrected magnitude of the first spectral
# harmonic located at frequency \omega_0 [H*(\omega_0)], where 
# \omega_0 = 2\pi F_0 and F_0 is the fundamental frequency, is given by
#
#	   									   (1 - 2r_i \cos(\omega_i) + r^2_i)^2
# H(\omega_0) - \sum_{i=1}^{N} 10\log_10 ( ------------------------------------- )
#	   							 	    (1 - 2r_i \cos(\omega_0 + \omega_i) + r^2_i) * 
#	   								    (1 - 2r_i \cos(\omega_0 - \omega_i) + r^2_i)
#
# with r_i = e^{-\pi B_i/F_s} and \omega_i = 2\pi F_i/F_s where F_i and
# B_i are the frequencies and bandwidths of the ith formant, F_s is the 
# sampling frequency, and N is the number of formants to be corrected for. 
# H(\omega_o) is the magnitude of the first harmonic from the speech 
# spectrum and H*(\omega_0) represents the corrected magnitude and should
# coincide with the magnitude of the source spectrum at \omega_0. Note that 
# all magnitudes are in decibels." (2285-6)
# 
# Note that there is an error in the above (from the 2007 paper): the
# frequency of ALL harmonics needs to be corrected for the sampling 
# frequency F_s. This is correctly noted in Iseli & Alwan (2004), Sec. 3.
#
# Formant bandwidths are calculated using the formula in Mannell (1998):
#
# B_i = (80 + 120F_i/5000)
#
# "For H1* and H2*, the correction was for the ﬁrst and second formant 
# (F1 and F2) inﬂuence with N=2 in Eq. (A5). For A3*, the first three 
# formants were corrected for (N=3) and there was no normalization to 
# a neutral vowel; recall that our correction accounts for formant 
# frequencies and their bandwidths." (2286-7)
#
# The authors note that the measures are dependent on vowel quality (F1) 
# and vowel type, but this is not expressly corrected for here. 
#
# See the paper (or the algorithm coded below) for details.  
#
# This script is released under the GNU General Public License version 3.0 
# The included file "gpl-3.0.txt" or the URL "http://www.gnu.org/licenses/gpl.html" 
# contains the full text of the license.

form Parameters for spectral tilt measure following Iseli et al.
 comment TextGrid interval to measure.  If numeric, check the box.
 natural tier 1
 integer interval_number 0
 text interval_label v1
 comment Window parameters
 real windowPosition 0.5
 positive windowLength 0.025
 comment Output
 boolean output_to_matrix 1
 boolean saveAsEPS 0
 sentence inputdir /home/username/data/
 comment Manually check token?
 boolean manualCheck 1
 comment Analysis parameters
 positive maxDisplayHz 4000
 positive measure 2
 positive points 3
endform

###
### First, check that proper objects are present and selected.
###
numSelectedSound = numberOfSelected("Sound")
numSelectedTextGrid = numberOfSelected("TextGrid")
numSelectedPointProcess = numberOfSelected("PointProcess")
numSelectedFormant = numberOfSelected("Formant")
numSelectedPitch = numberOfSelected("Pitch")
if (numSelectedSound<>1 or numSelectedTextGrid<>1 or numSelectedPointProcess<>1 or numSelectedFormant<>1 or numSelectedPitch<>1)
 exit Select one Sound, one TextGrid, one PointProcess, one Pitch, and one Formant object.
endif
name$ = selected$("Sound")
soundID = selected("Sound")
textGridID = selected("TextGrid")
pointProcessID = selected("PointProcess")
pitchID = selected("Pitch")
formantID = selected("Formant")
### (end object check)

###
### Second, establish time domain.
###
select textGridID
if 'interval_number' > 0
 intervalOfInterest = interval_number
else
 numIntervals = Get number of intervals... 'tier'
 for currentInterval from 1 to 'numIntervals'
  currentIntervalLabel$ = Get label of interval... 'tier' 'currentInterval'
  if currentIntervalLabel$==interval_label$
   intervalOfInterest = currentInterval
  endif
 endfor
endif

startTime = Get starting point... 'tier' 'intervalOfInterest'
endTime = Get end point... 'tier' 'intervalOfInterest'
### (end time domain check)

### Decide what times to measure at 
### For the midpoint, just measure at 50%
if measure = 1
	points = 1
	mid1 = (startTime + endTime) / 2 
### For the second measurement choice, we'll measure at 25%, 50%, and 75%
elsif measure = 2
	points = 3
	mid1 = startTime + (0.25 * (endTime - startTime))
	mid2 = (startTime + endTime) / 2
	mid3 = startTime + (0.75 * (endTime - startTime))
### For equidistant points we have to calculate the times
else
	for point from 1 to points
	## Ensure we are at least 12.5ms from the edges
	mid'point' = (((point - 1)/(points - 1)) * ((endTime-0.0125) - (startTime+0.0125))) + (startTime + 0.0125)
	endfor
endif
### (end definition of measurement points ###

### Build Matrix object (once) ###
if output_to_matrix
    Create simple Matrix... IseliMeasures points 12 0
    matrixID = selected("Matrix")
endif
### (end build matrix object) ###

for i from 1 to points

	## Generate a slice around the measurement point ##
	sliceStart = mid'i' - ('windowLength' / 2)
	sliceEnd = mid'i' + ('windowLength' / 2)

	##############
	## Estimate f0 
	##############
	select 'pitchID'
	f0 = Get value at time... mid'i' Hertz Linear
	if f0 = undefined
		f0 = 0
	endif
	f02 = 2*f0

	################
	# Get F1, F2, F3
	################
    select 'formantID'
	f1hzpt = Get value at time... 1 mid'i' Hertz Linear
	f1bw = Get bandwidth at time... 1 mid'i' Hertz Linear
	f2hzpt = Get value at time... 2 mid'i' Hertz Linear
	f2bw = Get bandwidth at time... 2 mid'i' Hertz Linear
	xx = Get minimum number of formants
	if xx > 2
		f3hzpt = Get value at time... 3 mid'i' Hertz Linear
		f3bw = Get bandwidth at time... 3 mid'i' Hertz Linear
	else
		f3hzpt = 0
		f3bw = 0
	endif

	#####################
	# Measure H1, H2, H4
	#####################
	select 'pitchID'
	p10_mid'i' = mid'i' / 10
	select 'soundID'
	sample_rate = Get sampling frequency
	Extract part... 'sliceStart' 'sliceEnd' Hanning 1 yes
	windowedSoundID = selected("Sound")
	To Spectrum... yes
	spectrumID = selected("Spectrum")
	To Ltas (1-to-1)
	ltasID = selected("Ltas")
	select 'ltasID'
	lowerbh1 = mid'i' - p10_mid'i'
	upperbh1 = mid'i' + p10_mid'i'
	lowerbh2 = (mid'i' * 2) - (p10_mid'i' * 2)
	upperbh2 = (mid'i' * 2) + (p10_mid'i' * 2)
	lowerbh4 = (mid'i' * 4) - (p10_mid'i' * 2)
	upperbh4 = (mid'i' * 4) + (p10_mid'i' * 2)
	h1db = Get maximum... 'lowerbh1' 'upperbh1' None
	h1hz = Get frequency of maximum... 'lowerbh1' 'upperbh1' None
	h2db = Get maximum... 'lowerbh2' 'upperbh2' None
	h2hz = Get frequency of maximum... 'lowerbh2' 'upperbh2' None
	h4db = Get maximum... 'lowerbh4' 'upperbh4' None
	h4hz = Get frequency of maximum... 'lowerbh4' 'upperbh4' None
	rh1hz = round('h1hz')
	rh2hz = round('h2hz')

	#####################
	# Measure A1, A2, A3 
	#####################
	p10_f1hzpt = 'f1hzpt' / 10
	p10_f2hzpt = 'f2hzpt' / 10
	p10_f3hzpt = 'f3hzpt' / 10
	lowerba1 = 'f1hzpt' - 'p10_f1hzpt'
	upperba1 = 'f1hzpt' + 'p10_f1hzpt'
	lowerba2 = 'f2hzpt' - 'p10_f2hzpt'
	upperba2 = 'f2hzpt' + 'p10_f2hzpt'
	lowerba3 = 'f3hzpt' - 'p10_f3hzpt'
	upperba3 = 'f3hzpt' + 'p10_f3hzpt'
	a1db = Get maximum... 'lowerba1' 'upperba1' None
	a1hz = Get frequency of maximum... 'lowerba1' 'upperba1' None
	a2db = Get maximum... 'lowerba2' 'upperba2' None
	a2hz = Get frequency of maximum... 'lowerba2' 'upperba2' None
	a3db = Get maximum... 'lowerba3' 'upperba3' None
	a3hz = Get frequency of maximum... 'lowerba3' 'upperba3' None
                            
	#########################################
	# Calculate adjustments relative to F1-F3
	#########################################
	@correct_iseli (h1db, h1hz, f1hzpt, f1bw, f2hzpt, f2bw, f3hzpt, f3bw, sample_rate)
	h1adj = correct_iseli.result
	@correct_iseli (h2db, h2hz, f1hzpt, f1bw, f2hzpt, f2bw, f3hzpt, f3bw, sample_rate)
	h2adj = correct_iseli.result
	@correct_iseli (h4db, h4hz, f1hzpt, f1bw, f2hzpt, f2bw, f3hzpt, f3bw, sample_rate)
	h4adj = correct_iseli.result
	@correct_iseli (a1db, a1hz, f1hzpt, f1bw, f2hzpt, f2bw, f3hzpt, f3bw, sample_rate)
	a1adj = correct_iseli.result
	@correct_iseli (a2db, a2hz, f1hzpt, f1bw, f2hzpt, f2bw, f3hzpt, f3bw, sample_rate)
	a2adj = correct_iseli.result
	@correct_iseli (a3db, a3hz, f1hzpt, f1bw, f2hzpt, f2bw, f3hzpt, f3bw, sample_rate)
	a3adj = correct_iseli.result


	###########################################
	# Display results BROKEN AS OF 27 JAN 2016
	###########################################
	if (manualCheck or saveAsEPS)
	
		# Generate output in picture window
	
	 	# Setup
	 	Erase all
	 	Select outer viewport... 0 6 0 4
	
		# Display spectrum
		select 'ltasID'
		minDB = Get minimum... 0 'maxDisplayHz' None
		maxDB = Get maximum... 0 'maxDisplayHz' None
		dBrange = maxDB-minDB
		maxDB = maxDB + 0.1*dBrange
	
	 	Black
	 	Draw... 0 'maxDisplayHz' 'minDB' 'maxDB' yes  Curve
	
	 	# Identify H1 
	 	Green
	 	circleRadius = maxDisplayHz / 100
	 	#One mark left... 'h1' no no no H1
	 	Draw line... 0 'h1' 'f0' 'h1'
	 	Draw circle... 'f0' 'h1' 'circleRadius'
	 	h1dBlabel = h1 + 0.05*dBrange
	 	Text... 'f0' Centre 'h1dBlabel' Half  H1
	
	 	# Identify H2 
	 	#One mark left... 'h2' no no no H2
	 	Draw line... 0 'h2' 'f02' 'h2'
	 	Draw circle... 'f02' 'h2' 'circleRadius'
	 	h2dBlabel = h2 + 0.05*dBrange
	 	Text... 'f02' Centre 'h2dBlabel' Half  H2
	
	 	# Identify A3
	 	#One mark left... 'a3' no no no A3
	 	Draw line... 0 'a3' 'a3Hz' 'a3'
	 	Draw circle... 'a3Hz' 'a3' 'circleRadius'
	 	a3dBlabel = a3 + 0.05*dBrange
	 	Text... 'a3Hz' Centre 'a3dBlabel' Half  A3
	
	 	Red
	 	#circleRadius = circleRadius / 2
	 	#One mark right... 'h1adj' no no no H1*
	 	#Draw line... 'f0' 'h1adj' 'maxDisplayHz' 'h1adj'
	 	Draw circle... 'f0' 'h1adj' 'circleRadius'
	
	 	#One mark right... 'h2adj' no no no H2*
	 	#Draw line... 'f02' 'h2adj' 'maxDisplayHz' 'h2adj'
	 	Draw circle... 'f02' 'h2adj' 'circleRadius'
	
	 	#One mark right... a3adj no no no  A3*
	 	#Draw line... 'a3Hz' 'a3adj' 'maxDisplayHz' 'a3adj'
	 	Draw circle... 'a3Hz' 'a3adj' 'circleRadius'
	 	Black
	
	 	# Object name at bottom
	 	Select outer viewport... 2.5 3.5 4 4.5
	 	Text... 0 Centre 0 Half Iseli's corrected H1*-H2*, H1*-A3*

		# Output at top
	 	Select outer viewport... 0 6 0 4.5
		rh1 = round('h1')
		rh1adj = round('h1adj')
		rh2 = round('h2')
		rh2adj = round('h2adj')
		ra3 = round('a3')
		ra3adj = round('a3adj')
		rh1h2 = rh1 - rh2
		rh1a3 = rh1 - ra3
		rdiffh1h2 = rh1adj - rh2adj
		rdiffh1a3 = rh1adj - ra3adj
		Text top... no H1-H2: 'rh1h2'   H1*-H2*: 'rdiffh1h2'   H1-A3: 'rh1a3'    H1*-A3*: 'rdiffh1a3'
		# Set selection to whole in case user wants to save display as sample
	 	Select outer viewport... 0 6 0 4.5
	
	 	if saveAsEPS
	  		Write to EPS file... 'inputdir$''name$'.H1A3.eps
	 	endif
	 
		if manualCheck
	  		pause Press <Continue> to proceed to the next token, or <Stop> to halt the analysis.
	 	endif
	endif
	## end of manual check
	#
	if output_to_matrix
		select 'matrixID'
		Set value... i 1 'h1db'
		Set value... i 2 'h2db'
		Set value... i 2 'h4db'
		Set value... i 4 'a1db'
		Set value... i 5 'a2db'
		Set value... i 6 'a3db'
		Set value... i 7 'h1adj'
		Set value... i 8 'h2adj'
		Set value... i 9 'h4adj'
		Set value... i 10 'a1adj'
		Set value... i 11 'a2adj'
		Set value... i 12 'a3adj'
	else
		select 'soundID'
		plus 'textGridID'
		plus 'pointProcessID'
		plus 'formantID'
	endif
	## end of output_to_matrix

	###
	# Clean up generated objects
	###
	select 'windowedSoundID'
	plus 'spectrumID'
	plus 'ltasID'
	Remove
endfor


########################################################
## below taken from Collier's script/VoiceSauce codebase
########################################################

procedure correct_iseli (dB, hz, f1hz, f1bw, f2hz, f2bw, f3hz, f3bw, fs)
    dBc = dB
    for corr_i from 1 to 3
        fx = f'corr_i'hz
        bx = f'corr_i'bw
        f = dBc
        if fx <> 0
            r = exp(-pi*bx/fs)
            omega_x = 2*pi*fx/fs
            omega  = 2*pi*f/fs
            a = r ^ 2 + 1 - 2*r*cos(omega_x + omega)
            b = r ^ 2 + 1 - 2*r*cos(omega_x - omega)

            # corr = -10*(log10(a)+log10(b));   # not normalized: H(z=0)~=0
            numerator = r ^ 2 + 1 - 2 * r * cos(omega_x)
            corr = -10*(log10(a)+log10(b)) + 20*log10(numerator)
            dBc = dBc - corr
        endif
    endfor
    .result = dBc
endproc

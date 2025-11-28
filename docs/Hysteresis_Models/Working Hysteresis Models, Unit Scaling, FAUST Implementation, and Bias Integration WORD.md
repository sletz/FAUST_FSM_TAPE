![Image: image_001](./Working%20Hysteresis%20Models,%20Unit%20Scaling,%20FAUST%20Implementation,%20and%20Bias%20Integration%20WORD_images/image_001.png)

Real-Time Audio DSP Research: Working Hysteresis Models, Unit Scaling, FAUST Implementation, and Bias Integration

# Working Hysteresis Models for Real-Time Audio DSP

**Jiles-Atherton Model Implementation**

The **Jiles-Atherton J A) model** has emerged as the gold standard for real-time magnetic hysteresis emulation in analog tape modeling. This physics-based approach provides authentic tape saturation characteristics while maintaining computational efficiency.  1 2

The core differential equation for the J A model describes magnetization M) as a function of magnetic field H  1

dM/dH = (1-c)δM(Man-M) / ((1-c)δSk - α(Man-M)) + c(dMan/dH)

Where:

![Image: image_002](./Working%20Hysteresis%20Models,%20Unit%20Scaling,%20FAUST%20Implementation,%20and%20Bias%20Integration%20WORD_images/image_002.png) c is the ratio of reversible to total magnetization (typically 1.7e-1

![Image: image_003](./Working%20Hysteresis%20Models,%20Unit%20Scaling,%20FAUST%20Implementation,%20and%20Bias%20Integration%20WORD_images/image_003.png) k controls hysteresis loop width (related to coercivity, 27 kA/m for ferric oxide)

![Image: image_004](./Working%20Hysteresis%20Models,%20Unit%20Scaling,%20FAUST%20Implementation,%20and%20Bias%20Integration%20WORD_images/image_004.png) α is the mean field parameter 1.6e-3

![Image: image_005](./Working%20Hysteresis%20Models,%20Unit%20Scaling,%20FAUST%20Implementation,%20and%20Bias%20Integration%20WORD_images/image_005.png) Man is the anhysteretic magnetization using the Langevin function

![Image: image_006](./Working%20Hysteresis%20Models,%20Unit%20Scaling,%20FAUST%20Implementation,%20and%20Bias%20Integration%20WORD_images/image_006.png) δS and δM are switching parameters based on field direction

# Real-Time Implementation Strategies

**Numerical Solvers**: Professional implementations use various equation solvers:  2

**Runge-Kutta methods** RK2, RK4 Computationally cheaper but less accurate

**Newton-Raphson iterations** NR4, NR8 More accurate but computationally intensive

**State Transition Networks STN** : Approximation designed for efficiency

ChowTape's implementation demonstrates that **4th-order Runge-Kutta** provides the best balance of accuracy and computational efficiency for real-time use. The system requires careful numerical considerations, including Langevin function approximations for values near zero:  1

L(x) = (|x| > 10^-4) ? coth(x) - 1/x : x/3

# Simplified Backlash Operator Approach

An alternative approach uses **backlash operators** for magnetic tape emulation. This method is less computationally intensive than full J A modeling while still capturing essential hysteresis characteristics. The backlash operator alternately transfers signals between linear sections of the magnetization curve, effectively modeling the non-linear tape response.  3

# Proper Unit Scaling for Magnetic Models

**Physical to Normalized Parameter Mapping**

Professional tape emulations handle unit conversion through careful parameter scaling to maintain the 1 normalized range while preserving physical accuracy.  1

**Key Physical Constants**:

![Image: image_007](./Working%20Hysteresis%20Models,%20Unit%20Scaling,%20FAUST%20Implementation,%20and%20Bias%20Integration%20WORD_images/image_007.png) Magnetic Saturation Ms 3.5e5 A/m for ferric oxide tape

![Image: image_008](./Working%20Hysteresis%20Models,%20Unit%20Scaling,%20FAUST%20Implementation,%20and%20Bias%20Integration%20WORD_images/image_008.png) Hysteresis Loop Width (k): 27 kA/m (approximated as coercivity) ![Image: image_009](./Working%20Hysteresis%20Models,%20Unit%20Scaling,%20FAUST%20Implementation,%20and%20Bias%20Integration%20WORD_images/image_009.png) Anhysteretic parameter (a): 22 kA/m

![Image: image_010](./Working%20Hysteresis%20Models,%20Unit%20Scaling,%20FAUST%20Implementation,%20and%20Bias%20Integration%20WORD_images/image_010.png) Record head magnetic field: 5e5 A/m peak-to-peak **Normalization Strategy**:

**Input scaling**: Audio signals 1) are scaled to appropriate magnetic field levels through drive controls

**Internal processing**: Maintains physical units for accurate hysteresis modeling

**Output scaling**: Results are scaled back to 1 range for digital audio systems

The ChowTape implementation demonstrates this approach, where the **Drive** parameter controls input amplification affecting the nonlinear hysteresis characteristics, while **Saturation** controls the level at which the hysteresis function saturates.  2

# Bias Signal Integration

Tape bias implementation requires careful amplitude relationships. The bias signal amplitude should be approximately **5 10 times larger** than the audio signal amplitude to properly linearize the magnetic response. For the Sony TC 260 model, a bias gain of 5 relative to the input signal at 55 kHz frequency provides optimal results.  1

# Stable Feedback Loop Implementation in FAUST

**The Tilde Operator and Stateful Systems**

FAUST's **tilde operator (~ )** is specifically designed for implementing stateful nonlinear systems with feedback. The operator provides automatic one-sample delay, which is essential for digital feedback stability.  4

**Three Implementation Approaches**:  4

**Basic Syntax with Tilde Operator**:

lowpass(cf, x) = b0 \* x : + ~ \*(-a1) with {

b0 = 1 + a1;

a1 = exp(-w(cf)) \* -1;

w(f) = 2 \* ma.PI \* f / ma.SR;

};

**With Environment and Auxiliary Functions**:

lowpass(cf, x) = loop ~ \_ with {

loop(feedback) = b0 \* x - a1 \* feedback; b0 = 1 + a1;

a1 = exp(-w(cf)) \* -1;

w(f) = 2 \* ma.PI \* f / ma.SR;

};

**Letrec Environment**:

lowpass(cf, x) = y letrec {

'y = b0 \* x - a1 \* y;

// ... parameter definitions

};

# Common Pitfalls and Best Practices

**Stability Considerations**:

![Image: image_011](./Working%20Hysteresis%20Models,%20Unit%20Scaling,%20FAUST%20Implementation,%20and%20Bias%20Integration%20WORD_images/image_011.png) Always ensure at least one-sample delay in feedback paths ![Image: image_012](./Working%20Hysteresis%20Models,%20Unit%20Scaling,%20FAUST%20Implementation,%20and%20Bias%20Integration%20WORD_images/image_012.png) Use appropriate numerical ranges to prevent overflow

![Image: image_013](./Working%20Hysteresis%20Models,%20Unit%20Scaling,%20FAUST%20Implementation,%20and%20Bias%20Integration%20WORD_images/image_013.png) Implement soft limiting for extreme parameter values

![Image: image_014](./Working%20Hysteresis%20Models,%20Unit%20Scaling,%20FAUST%20Implementation,%20and%20Bias%20Integration%20WORD_images/image_014.png) Consider oversampling for nonlinear systems to prevent aliasing

**Memory Management**: FAUST's recursive operators automatically handle state variables. The apostrophe prefix ('y) in letrec indicates a delayed version of the signal, essential for preventing algebraic loops.  4

**Complex Feedback Systems**: For multi-state systems (like quadrature oscillators), use the route

primitive to properly distribute feedback signals to appropriate inputs.  4

# Bias Oscillator Integration

**Bias Amplitude and Frequency Requirements**

Professional tape machines use **AC bias** with specific characteristics:  5 6

**Amplitude Requirements**:

![Image: image_015](./Working%20Hysteresis%20Models,%20Unit%20Scaling,%20FAUST%20Implementation,%20and%20Bias%20Integration%20WORD_images/image_015.png) Bias amplitude should be **5 30 times** the signal amplitude 7  ![Image: image_016](./Working%20Hysteresis%20Models,%20Unit%20Scaling,%20FAUST%20Implementation,%20and%20Bias%20Integration%20WORD_images/image_016.png) Typical bias voltages range from **30 90V peak-to-peak**  8

![Image: image_017](./Working%20Hysteresis%20Models,%20Unit%20Scaling,%20FAUST%20Implementation,%20and%20Bias%20Integration%20WORD_images/image_017.png) For digital implementation, bias gain of **5 10x** relative to input signal 1  **Frequency Specifications**:

![Image: image_018](./Working%20Hysteresis%20Models,%20Unit%20Scaling,%20FAUST%20Implementation,%20and%20Bias%20Integration%20WORD_images/image_018.png) Bias frequency: **40 150 kHz** (commonly 55 105 kHz)  9 6

![Image: image_019](./Working%20Hysteresis%20Models,%20Unit%20Scaling,%20FAUST%20Implementation,%20and%20Bias%20Integration%20WORD_images/image_019.png) Must be at least **3.5 times** the highest audio frequency 7

![Image: image_020](./Working%20Hysteresis%20Models,%20Unit%20Scaling,%20FAUST%20Implementation,%20and%20Bias%20Integration%20WORD_images/image_020.png) Higher bias frequencies 105 kHz) found on high-quality decks for extended response 9

# Integration Stage and Implementation

**Signal Path Integration**:  8

Audio signal passes through record amplifier

Bias signal is **passively added** to the audio signal

Combined signal feeds the record head

Bias trap filters prevent bias from feeding back into record amplifier **Implementation in Real-Time Systems**:  1

I\_head(n) = I\_input(n) + B \* cos(2π \* f\_bias \* n \* T)

Where B is the bias amplitude and f\_bias is the bias frequency (typically 55 kHz).

# Preventing Numerical Instability

**Oversampling Requirements**: Bias frequencies above Nyquist require significant oversampling. ChowTape uses **16x oversampling** to handle 55 kHz bias at standard sample rates while preventing aliasing from the nonlinear hysteresis processing.  1

**Bias Traps**: Implement **high-pass filtering** at the output to remove bias frequencies before the signal reaches the audio path. This prevents bias oscillator signals from causing instability in downstream processing.  10

**Parameter Limits**: Implement **soft limiting** on bias parameters to prevent extreme values from causing numerical instability. Professional implementations include automatic level adjustments based on tape type and bias settings.

The research demonstrates that proper bias implementation is crucial for authentic tape emulation, as it directly affects the hysteresis curve width and enables the characteristic "deadzone" effect associated with underbiased tape. The bias signal effectively switches the

magnetization between linear regions of the hysteresis curve, enabling more linear recording characteristics while preserving the musical saturation effects that make analog tape desirable.

2

⁂

<https://www.dafx.de/paper-archive/2019/DAFx2019_paper_3.pdf>

<https://chowdsp.com/manuals/ChowTapeManual.pdf>

<https://www.kvraudio.com/forum/viewtopic.php?t=499395>

<https://www.dariosanfilippo.com/posts/2020/11/28/faust_recursive_circuits.html>

<https://www.aes.org/aeshc/docs/3mtape/soundtalk/soundtalkv1n2.pdf>

<https://en.wikipedia.org/wiki/Tape_bias>

[https://www.cieri.net/Documenti/Misure audio/Hewlett-Packard - Application Note AN89 Magnetic](https://www.cieri.net/Documenti/Misure%20audio/Hewlett-Packard%20-%20Application%20Note%20AN89%20-%20Magnetic%20Tape%20Recording%20Handbook%20%281967%29.pdf) [Tape Recording Handbook 1967 .pdf](https://www.cieri.net/Documenti/Misure%20audio/Hewlett-Packard%20-%20Application%20Note%20AN89%20-%20Magnetic%20Tape%20Recording%20Handbook%20%281967%29.pdf)

<https://www.youtube.com/watch?v=64wWeS7BdS0>

[https://www.diyaudio.com/community/threads/tapedeck-bias-frequency -circuitry.227093/](https://www.diyaudio.com/community/threads/tapedeck-bias-frequency-circuitry.227093/)

<https://www.youtube.com/watch?v=YBif0fsoxMY>

<http://arxiv.org/pdf/2301.08533.pdf>

<http://arxiv.org/pdf/2501.03427.pdf>

<http://arxiv.org/pdf/2401.16840.pdf>

<https://dl.acm.org/doi/pdf/10.1145/3613424.3614257>

<https://arxiv.org/pdf/2012.10392.pdf>

<https://apps.dtic.mil/sti/tr/pdf/AD0658329.pdf>

[https://www.steinberg.help/r/cubase-pro/13.0/en/cubase\_nuendo/topics/mixconsole/mixconsole\_tape\_s](https://www.steinberg.help/r/cubase-pro/13.0/en/cubase_nuendo/topics/mixconsole/mixconsole_tape_saturation_r.html) [aturation\_r.html](https://www.steinberg.help/r/cubase-pro/13.0/en/cubase_nuendo/topics/mixconsole/mixconsole_tape_saturation_r.html)

<https://www.youtube.com/watch?v=OV6xx213QQ0>

[https://www.steinberg.help/r/cubase-elements/13.0/en/cubase\_nuendo/topics/mixconsole/mixconsole\_t](https://www.steinberg.help/r/cubase-elements/13.0/en/cubase_nuendo/topics/mixconsole/mixconsole_tape_saturation_r.html) [ape\_saturation\_r.html](https://www.steinberg.help/r/cubase-elements/13.0/en/cubase_nuendo/topics/mixconsole/mixconsole_tape_saturation_r.html)

<https://www.reddit.com/r/musicproduction/comments/1doqpvs/what_are_the_best_tape_emulators_w/>

<http://thesai.org/Publications/ViewPaper?Volume=8&Issue=4&Code=ijacsa&SerialNo=62>

<https://github.com/hollance/TheKissOfShame>

<https://sonification.de/handbook/download/TheSonificationHandbook-chapter15.pdf>

[https://uadforum.com/community/index.php?threads%2Femulating-tape-feasible-accurate-really-wort](https://uadforum.com/community/index.php?threads%2Femulating-tape-feasible-accurate-really-worth-it.9630%2F) [h-it.9630%2F](https://uadforum.com/community/index.php?threads%2Femulating-tape-feasible-accurate-really-worth-it.9630%2F)

[https://data.epo.org/publication-server/rest/v1.0/publication-dates/19950719/patents/EP0338812NWB1/](https://data.epo.org/publication-server/rest/v1.0/publication-dates/19950719/patents/EP0338812NWB1/document.pdf) [document.pdf](https://data.epo.org/publication-server/rest/v1.0/publication-dates/19950719/patents/EP0338812NWB1/document.pdf)

<https://www.youtube.com/watch?v=yLySxWQX5qo>

<https://patents.google.com/patent/US4229770A/en>

<https://gearspace.com/board/mastering-forum/342591-simulation-tape-saturation.html>

<https://www.hornetplugins.com/plugins/hornet-thenormalizer/>

[https://www.canford.co.uk/ProductResources/resources/M/MRL/02 209 MRL Choosing and using](https://www.canford.co.uk/ProductResources/resources/M/MRL/02-209%20MRL%20Choosing%20and%20using%20tapes.pdf) [tapes.pdf](https://www.canford.co.uk/ProductResources/resources/M/MRL/02-209%20MRL%20Choosing%20and%20using%20tapes.pdf)

<https://www.reddit.com/r/DSP/comments/1184yb0/how_can_i_do_an_tape_saturation_from_tanh_w/>

<https://www.semanticscholar.org/paper/51d4c0b849ebeb9fdd327bd1292076e22d598625>

<https://www.youtube.com/watch?v=FycDyFfB8ek>

<https://patents.google.com/patent/US3831196A/en>

<https://onlinelibrary.wiley.com/doi/10.1002/rnc.6173>

<https://www.semanticscholar.org/paper/e1b7fad25b3787dd1378ae63413fdc38d3e8fbc9>

<https://ieeexplore.ieee.org/document/8328857/>

<https://onlinelibrary.wiley.com/doi/10.1002/acs.3786>

<https://ieeexplore.ieee.org/document/10182235/>

[https://link.springer.com/10.1007/s11071 023 08767 2](https://link.springer.com/10.1007/s11071-023-08767-2)

[https://www.mdpi.com/2227 7390/8/8/1341](https://www.mdpi.com/2227-7390/8/8/1341)

<http://ieeexplore.ieee.org/document/7152426/>

<https://ieeexplore.ieee.org/document/1187467/>

<https://ieeexplore.ieee.org/document/9311697/>

<http://ieeexplore.ieee.org/document/4045528/>

<https://downloads.hindawi.com/journals/mpe/2013/646059.pdf>

<https://arxiv.org/pdf/2204.02545.pdf>

<https://arxiv.org/ftp/arxiv/papers/2311/2311.07089.pdf>

<http://arxiv.org/pdf/1408.2294.pdf>

<https://arxiv.org/pdf/1803.04874.pdf>

<https://arxiv.org/pdf/2010.04282.pdf>

[https://www.mdpi.com/1424 8220/21/4/1242/pdf](https://www.mdpi.com/1424-8220/21/4/1242/pdf)

<http://arxiv.org/pdf/2103.12666.pdf>

<https://ieeexplore.ieee.org/document/10265718/>

<http://arxiv.org/pdf/2404.07970.pdf>

[https://figshare.com/articles/journal\_contribution/Robust\_filtering\_for\_2 D\_systems\_with\_uncertain-varia](https://figshare.com/articles/journal_contribution/Robust_filtering_for_2-D_systems_with_uncertain-variance_noises_and_weighted_try-once-discard_protocols/21997520/1/files/39045416.pdf) [nce\_noises\_and\_weighted\_try-once-discard\_protocols/21997520/1/files/39045416.pdf](https://figshare.com/articles/journal_contribution/Robust_filtering_for_2-D_systems_with_uncertain-variance_noises_and_weighted_try-once-discard_protocols/21997520/1/files/39045416.pdf)

<https://www.diag.uniroma1.it/oriolo/amr/material/stability.pdf>

<https://faust.readthedocs.io/en/latest/reference/faust.stores.memory.html>

<https://www.semanticscholar.org/paper/90af62545e20dabaf848f3240db488d31026cefc>

<https://onlinelibrary.wiley.com/doi/book/10.1002/9781119125587>

[https://www.mdpi.com/1424 8220/21/4/1425](https://www.mdpi.com/1424-8220/21/4/1425)

<https://aes2.org/publications/elibrary-page/?id=22916>

<https://ieeexplore.ieee.org/document/8884709/>

<https://www.semanticscholar.org/paper/9819e7c90a22d27189b274de10911b2944b4d336>

<https://arxiv.org/pdf/2103.07220.pdf>

<http://arxiv.org/pdf/1311.0842.pdf>

<https://arxiv.org/pdf/2105.00236.pdf>

<http://www.e-ijaet.org/volume-6-issue-5.html>

<http://arxiv.org/pdf/2210.17152.pdf>

<http://arxiv.org/pdf/2001.04643.pdf>

[https://www.mdpi.com/2076 3417/6/5/134/pdf](https://www.mdpi.com/2076-3417/6/5/134/pdf)

<http://arxiv.org/pdf/2309.06649.pdf>

<http://arxiv.org/pdf/1907.00971.pdf>

<https://joss.theoj.org/papers/10.21105/joss.03613.pdf>

<http://www.96khz.org/htm/magneticmodelling.htm>

[https://www.lias-lab.fr/~eriketien/Files/Other/An Improved Jiles-Atherton Model for Least Square.pdf](https://www.lias-lab.fr/~eriketien/Files/Other/An%20Improved%20Jiles-Atherton%20Model%20for%20Least%20Square.pdf)

<https://www.sageaudio.com/articles/tape-emulation>

<https://pmc.ncbi.nlm.nih.gov/articles/PMC9658077/>

<https://documentation.dspconcepts.com/awe-designer/8.D.2.2/hysteresis>

[https://www.reddit.com/r/audioengineering/comments/127hb1c/moving\_away\_from\_waves\_favourite\_ta](https://www.reddit.com/r/audioengineering/comments/127hb1c/moving_away_from_waves_favourite_tape_emulation_w/) [pe\_emulation\_w/](https://www.reddit.com/r/audioengineering/comments/127hb1c/moving_away_from_waves_favourite_tape_emulation_w/)

[https://www.dafx.de/paper-archive/2016/dafxpapers/08 DAFx-16\_paper\_10 PN.pdf](https://www.dafx.de/paper-archive/2016/dafxpapers/08-DAFx-16_paper_10-PN.pdf)

<https://www.dafx.de/paper-archive/2023/DAFx23_paper_3.pdf>

[https://www.pluginboutique.com/articles/1885 The-14 Best-Tape-Emulation-Plugins-For-A Retro-Soun](https://www.pluginboutique.com/articles/1885-The-14-Best-Tape-Emulation-Plugins-For-A-Retro-Sound) [d](https://www.pluginboutique.com/articles/1885-The-14-Best-Tape-Emulation-Plugins-For-A-Retro-Sound)

<https://pubs.aip.org/aip/adv/article/15/3/035247/3341110/Application-of-the-Jiles-Atherton-model-to>

<https://www.sciencedirect.com/science/article/pii/S1474667015351028>

<https://www.airwindows.com/category/tape/>

<https://www.sciencedirect.com/science/article/abs/pii/S0952197624010625>

[https://dspconcepts.com/sites/default/files/2008 10 05\_real-time\_embedded\_audio\_signal\_processing.](https://dspconcepts.com/sites/default/files/2008-10-05_real-time_embedded_audio_signal_processing.pdf) [pdf](https://dspconcepts.com/sites/default/files/2008-10-05_real-time_embedded_audio_signal_processing.pdf)

<https://www.hornetplugins.com/hornet-tape-overview/>

[https://www.emerald.com/compel/article/36/5/1386/108227/Harmonic-balanced-Jiles-Atherton-hystere](https://www.emerald.com/compel/article/36/5/1386/108227/Harmonic-balanced-Jiles-Atherton-hysteresis) [sis](https://www.emerald.com/compel/article/36/5/1386/108227/Harmonic-balanced-Jiles-Atherton-hysteresis)

<https://www.elektronauts.com/t/what-is-the-best-tape-emulation-plugin-on-the-market/200941>

[https://macprovideo.com/article/audio-software/adding-analog-style-tape-saturation-effects-to-your-](https://macprovideo.com/article/audio-software/adding-analog-style-tape-saturation-effects-to-your-productions) [productions](https://macprovideo.com/article/audio-software/adding-analog-style-tape-saturation-effects-to-your-productions)

<https://www.degruyter.com/document/doi/10.1524/zkri.1991.197.14.75/html>

<http://arxiv.org/pdf/1402.2958.pdf>

<https://linkinghub.elsevier.com/retrieve/pii/S2352340924003433>

<http://diposit.ub.edu/dspace/bitstream/2445/22072/1/132554.pdf>

<http://arxiv.org/pdf/1007.2009.pdf>

<https://arxiv.org/pdf/2203.00890.pdf>

<https://www.mmnp-journal.org/articles/mmnp/pdf/2020/01/mmnp200017.pdf>

<http://link.aps.org/pdf/10.1103/PRXEnergy.3.011001>

<http://diposit.ub.edu/dspace/bitstream/2445/10484/1/151688.pdf>

<https://pmc.ncbi.nlm.nih.gov/articles/PMC9303976/>

<https://onlinelibrary.wiley.com/doi/pdfdirect/10.1002/bte2.20210017>

<https://arxiv.org/pdf/1406.4013.pdf>

[https://www.mdpi.com/2072 666X/13/4/509/pdf](https://www.mdpi.com/2072-666X/13/4/509/pdf)

<https://arxiv.org/html/2409.03304v1>

<https://arxiv.org/pdf/2211.12963.pdf>

<http://arxiv.org/pdf/2404.14004.pdf>

<https://arxiv.org/pdf/1610.09138.pdf>

<https://arxiv.org/pdf/1001.5195.pdf>

[https://www.mdpi.com/2076 0825/13/3/105/pdf?version=1709805887](https://www.mdpi.com/2076-0825/13/3/105/pdf?version=1709805887)

<https://forum.hise.audio/topic/11213/saturation-models-neve-tweaker-oxford-inflator-in-faust>

<https://www.kvraudio.com/forum/viewtopic.php?t=536112&start=30>

<https://www.youtube.com/watch?v=0ZAtn3SNQDw>

<https://github.com/LucaSpanedda/Digital_Reverberation_in_Faust>

<http://forum.pdpatchrepo.info/topic/13494/hysteresis>

<https://faust.grame.fr/community/powered-by-faust/>

<https://forum.hise.audio/topic/8037/create-simple-saturation-effect>

<https://forum.hise.audio/topic/11185/retro-80s-tape-wow-flutter-with-faust/17>

<https://forum.hise.audio/topic/11185/retro-80s-tape-wow-flutter-with-faust>

<https://www.youtube.com/watch?v=INlqClEOhak>

<https://faustdoc.grame.fr/examples/>

[https://www.reddit.com/r/audioengineering/comments/1dfgtxo/tape\_emulation\_plugins\_comparison\_firs](https://www.reddit.com/r/audioengineering/comments/1dfgtxo/tape_emulation_plugins_comparison_first_w/) [t\_w/](https://www.reddit.com/r/audioengineering/comments/1dfgtxo/tape_emulation_plugins_comparison_first_w/)

<https://www.opasquet.fr/gen-faust-max-externals/>

<https://www.youtube.com/watch?v=qnhG76_D9g4>

[https://uadforum.com/community/index.php?threads%2Fua-tape-emulations-which-is-most-realistic.6](https://uadforum.com/community/index.php?threads%2Fua-tape-emulations-which-is-most-realistic.64309%2F) [4309%2F](https://uadforum.com/community/index.php?threads%2Fua-tape-emulations-which-is-most-realistic.64309%2F)

<https://faustcloud.grame.fr/doc/examples/index.html>

<https://www.youtube.com/watch?v=C8XvzHcldjY>

<https://ieeexplore.ieee.org/document/10974180/>

<https://ieeexplore.ieee.org/document/10868777/>

<https://www.termedia.pl/doi/10.5114/ppn.2023.129053>

[https://www.phdynasty.ru/en/catalog/magazines/gynecology -obstetrics-and-perinatology/2024/volume](https://www.phdynasty.ru/en/catalog/magazines/gynecology-obstetrics-and-perinatology/2024/volume-23-issue-6/179336)

[23-issue-6/179336](https://www.phdynasty.ru/en/catalog/magazines/gynecology-obstetrics-and-perinatology/2024/volume-23-issue-6/179336)

[https://link.springer.com/10.1007/s12155 020 10205 9](https://link.springer.com/10.1007/s12155-020-10205-9)

[https://www.cureus.com/articles/233446-enhancing-medical-education-through-the-distribute-discuss](https://www.cureus.com/articles/233446-enhancing-medical-education-through-the-distribute-discuss-and-develop-method-a-comparative-study-of-small-group-discussions)

[-and-develop-method-a-comparative-study-of-small-group-discussions](https://www.cureus.com/articles/233446-enhancing-medical-education-through-the-distribute-discuss-and-develop-method-a-comparative-study-of-small-group-discussions)

<https://onlinelibrary.wiley.com/doi/10.1111/nicc.12621>

<https://www.worldscientific.com/doi/10.4015/S1016237223500370>

[https://bmcpalliatcare.biomedcentral.com/articles/10.1186/s12904 022 01109-w](https://bmcpalliatcare.biomedcentral.com/articles/10.1186/s12904-022-01109-w)

<https://library.imaging.org/archiving/articles/4/1/art00008>

<http://arxiv.org/pdf/2405.00003.pdf>

<https://arxiv.org/pdf/2305.16862.pdf>

<http://arxiv.org/pdf/1108.5976.pdf>

<http://arxiv.org/pdf/2206.13909.pdf>

[https://ars.copernicus.org/articles/21/89/2023/ars-21 89 2023.pdf](https://ars.copernicus.org/articles/21/89/2023/ars-21-89-2023.pdf)
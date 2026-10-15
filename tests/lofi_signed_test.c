/* SPDX-License-Identifier: MIT */
/* LOFI quantisation: freeze the original output while exercising negative
 * samples in both quantisers; run the same sweep with strict sanitizers. */
#define main engines_host_main
#include "fe_host.c"
#undef main

int main(void)
{
    static const int16_t crushes[] = {0, 64, 65, 127};
    static const int16_t notes[] = {24, 60, 108};
    static const int16_t duties[] = {0, 64, 127};
    uint64_t hash = UINT64_C(14695981039346656037);
    uint32_t cases = 0, negative = 0, positive = 0;
    for (uint32_t chip = 0; chip < 5; chip++)
        for (uint32_t wave = 0; wave < 5; wave++)
            for (uint32_t c = 0; c < NELEM(crushes); c++)
                for (uint32_t n = 0; n < NELEM(notes); n++)
                    for (uint32_t d = 0; d < NELEM(duties); d++)
                        for (uint32_t ramp = 0; ramp < 2; ramp++) {
                            track_t *t = &trk[0]; memset(t, 0, sizeof *t);
                            t->p[P_E0] = (int16_t)chip; t->p[P_E1] = (int16_t)wave;
                            t->p[P_E2] = duties[d]; t->p[P_E3] = crushes[c]; t->p[P_E7] = 127;
                            voice_t v = {0}; v.pitch16 = notes[n] * 16;
                            lofi_note_on(t, &v);
                            vmod_t m = {0}; m.pitch16 = v.pitch16; m.inc = pitch_inc(m.pitch16);
                            m.amp0 = 32767; m.amp1 = ramp ? 0 : 32767; m.envq15 = 32767;
                            for (uint32_t block = 0; block < 16; block++) {
                                int32_t out[CTL] = {0}; lofi_render(t, &v, out, CTL, &m);
                                for (uint32_t i = 0; i < CTL; i++) {
                                    negative += out[i] < 0; positive += out[i] > 0;
                                    hash = (hash ^ (uint32_t)out[i]) * UINT64_C(1099511628211);
                                }
                            }
                            cases++;
                        }
    printf("LOFI signed sweep: %u cases, negative=%u positive=%u hash=%016llx\n",
           cases, negative, positive, (unsigned long long)hash);
    return cases != 1800 || !negative || !positive || hash != UINT64_C(0xfaa686e0160c6df1);
}

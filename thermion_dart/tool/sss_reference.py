"""Independent normalized-Burley profile oracle; no GPU kernel code is copied.

Run: python3 tool/sss_reference.py
Integrates the analytic radial survival probability over angle to obtain the
1D marginal CDF. The GPU instead integrates Cartesian pixel footprints.
"""
import math
import unittest

RETAINED = 1 - 0.25 * math.exp(-16) - 0.75 * math.exp(-16/3)


def radial_cdf(r, d):
    return min(1.0, (1 - 0.25*math.exp(-r/d) - 0.75*math.exp(-r/(3*d))) / RETAINED)


def marginal_cdf(x, d, steps=1200):
    if x == 0:
        return 0.5
    tail = sum(1 - radial_cdf(abs(x)/math.cos((i+.5)*math.pi/(2*steps)), d)
               for i in range(steps)) / (2*steps)
    return tail if x < 0 else 1-tail


def kernel(d):
    support = math.ceil(16*d)
    return [(x, marginal_cdf(x+.5,d)-marginal_cdf(x-.5,d))
            for x in range(-support,support+1)]


def scatter(lighting, albedo, bypass, d):
    weights = kernel(d)
    out=[]
    for x, center in enumerate(lighting):
        delta=sum(w*(lighting[x+offset]-center) for offset,w in weights
                  if 0 <= x+offset < len(lighting))
        out.append(bypass[x]+albedo[x]*(center+delta))
    return out


class BurleyContract(unittest.TestCase):
    def test_radial_normalization_and_truncation(self):
        self.assertAlmostEqual(RETAINED, .9963790093708328, places=14)
        for d in [.001,.1,1,10]:
            self.assertEqual(radial_cdf(0,d),0)
            self.assertAlmostEqual(radial_cdf(16*d,d),1)

    def test_pixel_weights_are_positive_and_normalized(self):
        for d in [.05,.25,.5,1,2]:
            weights=kernel(d)
            self.assertTrue(all(w>=0 for _,w in weights))
            self.assertAlmostEqual(sum(w for _,w in weights),1,places=13)

    def test_profile_is_symmetric_and_scales_in_world_units(self):
        for x in [.1,1,3,8]:
            self.assertAlmostEqual(marginal_cdf(x,1)+marginal_cdf(-x,1),1)
            self.assertAlmostEqual(marginal_cdf(x,1),marginal_cdf(x*10,10))

    def test_texture_is_preserved_including_black(self):
        albedo=[0.0]*32+[0.5]*33
        self.assertEqual(scatter([2.0]*65,albedo,[0.0]*65,1),[2*a for a in albedo])

    def test_shadow_spreads_on_constant_albedo(self):
        light=[0.0]*32+[2.0]*33
        out=scatter(light,[.5]*65,[0.0]*65,1)
        self.assertGreater(out[31],.3)
        self.assertLess(out[32],.7)
        self.assertAlmostEqual(out[31]+out[32],1)

    def test_specular_and_emission_bypass(self):
        bypass=[0.0]*65
        bypass[32]=16
        self.assertEqual(scatter([0.0]*65,[.5]*65,bypass,1),bypass)

    def test_blender_45_radius_mapping(self):
        # Live bssrdf_setup -> bssrdf_setup_radius in Cycles 4.5 uses radius/(4*pi).
        # The older, albedo-dependent bssrdf_burley_setup helper is not called.
        for d in [.00015,.0003,.0006]:
            node_radius=4*math.pi*d
            self.assertAlmostEqual(node_radius*.25/math.pi,d)


if __name__=='__main__':
    unittest.main(verbosity=2)

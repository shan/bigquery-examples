# An example of a pattern one might use for Hardy-Weinberg Equilibrium
# queries upon 1,000 Genomes variants.  It is specifically computing
# the Hardy-Weinberg Equilibrium for the variants found in BRCA1 and
# then computing the chi-squared score for the observed verssus
# expected counts for the genotypes.

# http://scienceprimer.com/hardy-weinberg-equilibrium-calculator
# http://www.nfstc.org/pdi/Subject07/pdi_s07_m01_02.htm
# http://www.nfstc.org/pdi/Subject07/pdi_s07_m01_02.p.htm
# We have three genotypes, we therefore have 3 minus 1, or 2 degrees of freedom. 
# Chi-squared critical value for df=2, alpha=5*10^-8 is 29.71679
# > qchisq(1 - 5e-08, df=2) 
# [1] 33.62249

SELECT
  contig,
  position,
  END,
  reference_bases,
  alt,
  vt,
  ROUND(POW(hom_ref_count - expected_hom_ref_count,
      2)/expected_hom_ref_count +
    POW(hom_alt_count - expected_hom_alt_count,
      2)/expected_hom_alt_count +
    POW(het_count - expected_het_count,
      2)/expected_het_count,
    3) AS chi_squared_score,
  total_count,
  hom_ref_count,
  ROUND(expected_hom_ref_count,
    2) AS expected_hom_ref_count,
  het_count,
  ROUND(expected_het_count,
    2) AS expected_het_count,
  hom_alt_count,
  ROUND(expected_hom_alt_count,
    2) AS expected_hom_alt_count,
  ROUND(hw_alt_freq,
    4) AS hw_alt_freq,
  af,
FROM (
  SELECT
    contig,
    position,
    END,
    reference_bases,
    alt,
    vt,
    hom_ref_freq + (.5 * het_freq) AS hw_ref_freq,
    1 - (hom_ref_freq + (.5 * het_freq)) AS hw_alt_freq,
    POW(hom_ref_freq + (.5 * het_freq),
      2) * total_count AS expected_hom_ref_count,
    POW(1 - (hom_ref_freq + (.5 * het_freq)),
      2) * total_count AS expected_hom_alt_count,
    2 * (hom_ref_freq + (.5 * het_freq)) * (1 - (hom_ref_freq + (.5 * het_freq))) * total_count AS expected_het_count,
    total_count,
    hom_ref_count,
    het_count,
    hom_alt_count,
    hom_ref_freq,
    het_freq,
    hom_alt_freq,
    af,
  FROM (
    SELECT
      contig,
      position,
      END,
      reference_bases,
      GROUP_CONCAT(alternate_bases) WITHIN RECORD AS alt,
      vt,
      # exclude no-calls (-1); also 1000 genomes data IS bi-allelic
      SUM((0 = genotype.first_allele
          OR 1 = genotype.first_allele)
        AND (0 = genotype.second_allele
          OR 1 = genotype.second_allele)) WITHIN RECORD AS total_count,
      SUM(0 = genotype.first_allele
        AND 0 = genotype.second_allele) WITHIN RECORD AS hom_ref_count,
      SUM((0 = genotype.first_allele
          AND 1 = genotype.second_allele)
        OR (1 = genotype.first_allele
          AND 0 = genotype.second_allele)) WITHIN RECORD AS het_count,
      SUM(1 = genotype.first_allele
        AND 1 = genotype.second_allele) WITHIN RECORD AS hom_alt_count,
      SUM(0 = genotype.first_allele
        AND 0 = genotype.second_allele) / SUM((0 = genotype.first_allele
          OR 1 = genotype.first_allele)
        AND (0 = genotype.second_allele
          OR 1 = genotype.second_allele)) WITHIN RECORD AS hom_ref_freq,
      SUM((0 = genotype.first_allele
          AND 1 = genotype.second_allele)
        OR (1 = genotype.first_allele
          AND 0 = genotype.second_allele)) / SUM((0 = genotype.first_allele
          OR 1 = genotype.first_allele)
        AND (0 = genotype.second_allele
          OR 1 = genotype.second_allele)) WITHIN RECORD AS het_freq,
      SUM(1 = genotype.first_allele
        AND 1 = genotype.second_allele) / SUM((0 = genotype.first_allele
          OR 1 = genotype.first_allele)
        AND (0 = genotype.second_allele
          OR 1 = genotype.second_allele)) WITHIN RECORD AS hom_alt_freq,
      af,
    FROM
      [google.com:biggene:1000genomes.variants1kG]
    WHERE
      contig = '17'
      AND position BETWEEN 41196312
      AND 41277500))
WHERE
  # For chi-squared, expected counts must be at least 5 for each group
  expected_hom_ref_count >= 5.0
  AND expected_het_count >= 5.0
  AND expected_hom_alt_count >= 5.0
HAVING
  # Chi-squared critical value for df=2, alpha=5*10^-8 is 33.62249
  chi_squared_score >= 33.62249
ORDER BY
  chi_squared_score DESC,
  contig,
  position
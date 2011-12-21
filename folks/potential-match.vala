/*
 * Copyright (C) 2011 Collabora Ltd.
 *
 * This library is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this library.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authors:
 *       Raul Gutierrez Segales <raul.gutierrez.segales@collabora.co.uk>
 */

using Gee;

/**
 * Likely-ness of a potential match.
 *
 * Note that the order should be maintained.
 *
 * @since 0.5.0
 */
public enum Folks.MatchResult
{
  /**
   * Very low likelihood of a match.
   */
  VERY_LOW,

  /**
   * Low likelihood of a match.
   */
  LOW,

  /**
   * Medium likelihood of a match.
   */
  MEDIUM,

  /**
   * High likelihood of a match.
   */
  HIGH,

  /**
   * Very high likelihood of a match.
   */
  VERY_HIGH,

  /**
   * Minimum likelihood of a match.
   */
  MIN = VERY_LOW,

  /**
   * Maximum likelihood of a match.
   */
  MAX = VERY_HIGH
}

/**
 * This class provides functionality to explore a potential match between
 * two individuals.
 *
 * @since 0.5.0
 */
public class Folks.PotentialMatch : Object
{
  MatchResult _result;
  private Folks.Individual _individual_a;
  private Folks.Individual _individual_b;

  /**
   * A set of e-mail addresses known to be aliases of each other, such as
   * various forms of administrator address.
   *
   * @since 0.5.1
   */
  public static Set<string> known_email_aliases =
      new Gee.HashSet<string> (str_hash, str_equal);

  private static double _DIST_THRESHOLD = 0.70;
  private const string _SEPARATORS = "._-+";

  static construct
    {
      PotentialMatch.known_email_aliases.add ("admin");
      PotentialMatch.known_email_aliases.add ("abuse");
      PotentialMatch.known_email_aliases.add ("webmaster");
    }

  /**
   * Whether two individuals are likely to be the same person.
   *
   * @param a an individual to compare
   * @param b another individual to compare
   *
   * @since 0.5.0
   */
  public MatchResult potential_match (Individual a, Individual b)
    {
      this._individual_a = a;
      this._individual_b = b;
      this._result = MatchResult.MIN;

      if (this._individual_a.gender != Gender.UNSPECIFIED &&
          this._individual_b.gender != Gender.UNSPECIFIED &&
          this._individual_a.gender != this._individual_b.gender)
        {
          return this._result;
        }

      /* If individuals share common im-addresses */
      this._inspect_im_addresses ();
      if (this._result == MatchResult.MAX)
        return this._result;

      /* If individuals share common e-mails */
      this._inspect_emails ();
      if (this._result == MatchResult.MAX)
        return this._result;

      /* If individuals share common phone numbers */
      this._inspect_phone_numbers ();
      if (this._result == MatchResult.MAX)
        return this._result;

      /* they have the same (normalised) name? */
      this._name_similarity ();
      if (this._result == MatchResult.MAX)
        return this._result;

      return this._result;
    }

  private void _inspect_phone_numbers ()
    {
      var set_a = this._individual_a.phone_numbers;
      var set_b = this._individual_b.phone_numbers;

      foreach (var phone_fd_a in set_a)
        {
          foreach (var phone_fd_b in set_b)
            {
              if (phone_fd_a.values_equal (phone_fd_b))
                {
                  this._result = MatchResult.HIGH;
                  return;
                }
            }
        }
    }

  /* Approach:
   * - taking in account family, given, prefix, suffix and additional names
   *   we give some points for each non-empty match
   *
   * @since 0.5.0
   */
  private void _name_similarity ()
    {
      double similarity = 0.0;

      if (this._look_alike (this._individual_a.nickname,
              this._individual_b.nickname))
        {
          similarity += 0.20;
        }

      if (this._look_alike (this._individual_a.full_name,
              this._individual_b.full_name))
        {
          similarity += 0.70;
        }

      var _a = this._individual_a.structured_name;
      var _b = this._individual_b.structured_name;

      if (_a != null && _b != null)
        {
          var a = (!) _a;
          var b = (!) _b;

          if (a.is_empty () == false && a.equal (b))
            {
              this._result = MatchResult.HIGH;
              return;
            }

          if (Folks.Utils._str_equal_safe (a.given_name, b.given_name))
            similarity += 0.20;

          if (this._look_alike (a.family_name, b.family_name) &&
              this._look_alike (a.given_name, b.given_name))
            {
              similarity += 0.40;
            }

          if (Folks.Utils._str_equal_safe (a.additional_names,
                  b.additional_names))
            similarity += 0.5;

          if (Folks.Utils._str_equal_safe (a.prefixes, b.prefixes))
            similarity += 0.5;

          if (Folks.Utils._str_equal_safe (a.suffixes, b.suffixes))
            similarity += 0.5;
        }

      debug ("[name_similarity] Got %f\n", similarity);

      if (similarity >= this._DIST_THRESHOLD)
        this._result = this._inc_match_level (this._result, 2);
    }

  /**
   * Number of equal IM addresses between two individuals.
   *
   * This compares the addresses without comparing their associated protocols.
   *
   * @since 0.5.0
   */
  public void _inspect_im_addresses ()
    {
      var addrs = new HashSet<string> ();

      foreach (var im_a in this._individual_a.im_addresses.get_values ())
        {
          addrs.add (im_a.value);
        }

      foreach (var im_b in this._individual_b.im_addresses.get_values ())
        {
          if (addrs.contains (im_b.value) == true)
            {
              this._result = MatchResult.HIGH;
              return;
            }
        }
    }

  /**
   * Inspect email addresses.
   *
   * @since 0.5.0
   */
  private void _inspect_emails ()
    {
      var set_a = this._individual_a.email_addresses;
      var set_b = this._individual_b.email_addresses;

      foreach (var fd_a in set_a)
        {
          string[] email_split_a = fd_a.value.split ("@");

          /* Sanity check for valid e-mail addresses. */
          if (email_split_a.length < 2)
            {
              warning ("Invalid e-mail address when looking for potential " +
                  "match: %s", fd_a.value);
              continue;
            }

          string[] tokens_a =
            email_split_a[0].split_set (this._SEPARATORS);

          foreach (var fd_b in set_b)
            {
              string[] email_split_b = fd_b.value.split ("@");

              /* Sanity check for valid e-mail addresses. */
              if (email_split_b.length < 2)
                {
                  warning ("Invalid e-mail address when looking for " +
                      "potential match: %s", fd_b.value);
                  continue;
                }

              if (fd_a.value == fd_b.value)
                {
                  if (PotentialMatch.known_email_aliases.contains
                      (email_split_a[0]) == true)
                    {
                      if (this._result < MatchResult.HIGH)
                        {
                          this._result = MatchResult.LOW;
                        }
                    }
                  else
                    {
                      this._result = MatchResult.HIGH;
                      return;
                    }
                }
              else
                {
                  string[] tokens_b =
                    email_split_b[0].split_set (this._SEPARATORS);

                  /* Do we have: first.middle.last@ ~= fml@ ? */
                  if (this._check_initials_expansion (tokens_a, tokens_b))
                    {
                      this._result = MatchResult.MEDIUM;
                    }
                  /* So we have splitted the user part of the e-mail
                   * address into tokens. Lets see if there is some
                   * matches between tokens.
                   * As in: first.middle.last@ ~= [first,middle,..]@  */
                  else if (this._match_tokens (tokens_a, tokens_b))
                    {
                      this._result = MatchResult.MEDIUM;
                    }
               }
            }
        }
    }

  /* We are after:
   * you.are.someone@ =~ yas@
   */
  private bool _check_initials_expansion (string[] tokens_a, string[] tokens_b)
    {
      if (tokens_a.length > tokens_b.length &&
          tokens_b.length == 1)
        {
          return this._do_check_initials_expansion (tokens_a, tokens_b[0]);
        }
      else if (tokens_b.length > tokens_a.length &&
          tokens_a.length == 1)
        {
          return this._do_check_initials_expansion (tokens_b, tokens_a[0]);
        }
      return false;
    }

  private bool _do_check_initials_expansion (string[] expanded_name,
      string initials)
    {
      if (expanded_name.length != initials.length)
        return false;

      for (int i=0; i<expanded_name.length; i++)
        {
          if (expanded_name[i][0] != initials[i])
            return false;
        }

      return true;
    }

  /*
   * We should probably count how many tokens matched?
   */
  private bool _match_tokens (string[] tokens_a, string[] tokens_b)
    {
      /* To find matching items from 2 sets its more efficient
       * to make the outer loop go with the smaller set. */
      if (tokens_a.length > tokens_b.length)
        return this._do_match_tokens (tokens_a, tokens_b);
      else
        return this._do_match_tokens (tokens_b, tokens_a);
    }

  private bool _do_match_tokens (string[] bigger_set, string[] smaller_set)
    {
      for (var i=0; i < smaller_set.length; i++)
        {
          for (var j=0; j < bigger_set.length; j++)
            {
              if (smaller_set[i] == bigger_set[j])
                return true;
            }
        }

      return false;
    }

  private MatchResult _inc_match_level (
      MatchResult current_level, int times = 1)
    {
      MatchResult ret = current_level + times;
      if (ret > MatchResult.MAX)
        ret = MatchResult.MAX;

      return ret;
    }

  private bool _look_alike (string? a, string? b)
    {
      if (a == null || b == null)
        {
          return false;
        }

      // a and b look alike if their Jaro distance is over the threshold.
      return (this.jaro_dist ((!) a, (!) b) >= this._DIST_THRESHOLD);
    }

  /* Based on:
   *  http://en.wikipedia.org/wiki/Jaro%E2%80%93Winkler_distance
   *
   * d = 1/3 * ( m/|s1| + m/|s2| + (m - t)/m )
   *
   *   where
   *
   * m = matching characters
   * t = number of transpositions
   */
  private double jaro_dist (string s1, string s2)
    {
      double distance;
      int max = s1.length > s2.length ? s1.length : s2.length;
      int max_dist = (max / 2) - 1;
      double t;
      double m = (double) this._matches (s1, s2, max_dist, out t);
      double len_s1 = (double) s1.length;
      double len_s2 = (double) s2.length;
      double a = m / len_s1;
      double b = m / len_s2;
      double c = 0;

      if ((int) m > 0)
        c = (m - t) / m;

      distance = (1.0/3.0) * (a + b + c);

      debug ("[jaro_dist] Distance for %s and %s: %f\n", s1, s2, distance);

      return distance;
    }

  /* Calculate matches and transpositions as defined by the Jaro distance.
   */
  private int _matches (string s1, string s2, int max_dist, out double t)
    {
      int matches = 0;
      t = 0.0;

      for (int i=0; i < s1.length; i++)
        {
          var look_for = s1.slice (i, i + 1);
          int contains = this._contains (s2, look_for, i, max_dist);
          if (contains >= 0)
            {
              matches++;
              if (contains > 0)
                t += 1.0;
            }
        }

      debug ("%s and %s have %d matches and %f / 2 transpositions\n",
          s1, s2, matches, t);

      t = t / 2.0;
      return matches;
    }

  /* If haystack contains c in pos return 0, if it contains
   * it withing the bounds of max_dist return abs(pos-pos_found).
   * If its not found, return -1. */
  private int _contains (string haystack, string c, int pos, int max_dist)
    {
      if (pos < haystack.length && haystack.slice (pos, pos + 1) == c)
        return 0;

      for (int i=pos-max_dist; i <= pos + max_dist; i++)
        {
          if (i < 0 || i >= haystack.length)
            continue;

          var str = haystack.slice (i, i + 1);
          if (str == c)
            return (pos - i).abs ();
        }

      return -1;
    }
}

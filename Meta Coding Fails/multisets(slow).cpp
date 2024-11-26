#include <iostream>
#include <iterator>
#include <set>
#include <string>
#include <vector>

using namespace std;

struct Interval {
  long long a, s, e;

  Interval() : a(0), s(0), e(0) {}
  Interval(long long a_, long long s_, long long e_) : a(a_), s(s_), e(e_) {}

  Interval merge(const Interval &other) const {
    return Interval(a, min(s, other.s), max(e, other.e));
  }

  // Equality remains the same for all cases
  bool operator==(const Interval &other) const {
    return a == other.a && !(s > other.e || other.s > e);
  }

  void print() const { cout << "(" << a << "," << s << "," << e << ") "; }
};

// Comparator for sorting by anchor then start
struct CompareByAnchorStart {
  bool operator()(const Interval &lhs, const Interval &rhs) const {
    if (lhs.a != rhs.a)
      return lhs.a < rhs.a;
    return lhs.s < rhs.s;
  }
};

// Comparator for sorting by start then anchor
struct CompareByStartAnchor {
  bool operator()(const Interval &lhs, const Interval &rhs) const {
    if (lhs.s != rhs.s)
      return lhs.s < rhs.s;
    return lhs.a < rhs.a;
  }
};

using MultisetByAnchor = multiset<Interval, CompareByAnchorStart>;
using SetByAnchor = set<Interval, CompareByAnchorStart>;
using SetByStart = set<Interval, CompareByStartAnchor>;

SetByAnchor to_anchor_set(MultisetByAnchor container) {
  SetByAnchor result;
  if (container.empty())
    return result;
  Interval current = *container.begin();
  for (const Interval &v : container) {
    if (v.a == current.a && v == current) {
      current = current.merge(v);
    } else {
      if (current.a != 0 || (current.s != 0 || current.e != 0)) {
        result.insert(current);
      }
      current = v;
    }
  }
  if (current.a != 0 || (current.s != 0 || current.e != 0)) {
    result.insert(current);
  }
  return result;
}

SetByStart to_start_set(MultisetByAnchor container) {
  SetByStart result;
  if (container.empty())
    return result;
  Interval current = *container.begin();
  for (const Interval &v : container) {
    if (v.a == current.a && v == current) {
      current = current.merge(v);
    } else {
      if (current.a != 0 || (current.s != 0 || current.e != 0)) {
        result.insert(current);
      }
      current = v;
    }
  }
  if (current.a != 0 || (current.s != 0 || current.e != 0)) {
    result.insert(current);
  }
  return result;
}

void printSet(const MultisetByAnchor &container) {
  for (const auto &v : container) {
    v.print();
  }
  cout << endl;
}

void printSet(const SetByAnchor &container) {
  for (const auto &v : container) {
    v.print();
  }
  cout << endl;
}

void printSet(const SetByStart &container) {
  for (const auto &v : container) {
    v.print();
  }
  cout << endl;
}

long long getPlusSignCount(int N, vector<int> L, string D) {
  long long x = 0, y = 0, m = 0;
  MultisetByAnchor all_vlines;
  MultisetByAnchor all_hlines;

  for (int i = 0; i < N; i++) {
    m += L[i];
    if (i + 1 < N && D[i + 1] == D[i])
      continue;

    switch (D[i]) {
    case 'U':
      all_vlines.insert(Interval(x, y, y + m));
      y += m;
      break;
    case 'D':
      all_vlines.insert(Interval(x, y - m, y));
      y -= m;
      break;
    case 'L':
      all_hlines.insert(Interval(y, x - m, x));
      x -= m;
      break;
    case 'R':
      all_hlines.insert(Interval(y, x, x + m));
      x += m;
      break;
    }
    m = 0;
  }

  SetByAnchor hlines = to_anchor_set(all_hlines);
  SetByStart vlines = to_start_set(all_vlines);
  long long nplus = 0;
  auto hline_it = hlines.begin();
  for (const Interval &vline : vlines) {
    // Advance iterator to first potentially intersecting horizontal line
    while (hline_it != hlines.end() && hline_it->a <= vline.s) {
      hline_it++;
    }

    // Check all horizontal lines that could intersect with current vertical
    auto current_h = hline_it;
    while (current_h != hlines.end() && current_h->a < vline.e) {
      // Check if horizontal and vertical lines actually intersect
      if (current_h->s < vline.a && vline.a < current_h->e) {
        nplus++;
      }
      current_h++;
    }
  }
  return nplus;
}

int main() {
  int N = 9;
  vector<int> L = {6, 3, 4, 5, 1, 6, 3, 3, 4};
  string D = "ULDRULURD";
  long long expected = 4;
  long long result = getPlusSignCount(N, L, D);
  cout << "Expected: " << expected << ", Got: " << result << "\n\n\n";

  N = 8;
  L = {1, 1, 1, 1, 1, 1, 1, 1};
  D = "RDLUULDR";
  expected = 1;
  result = getPlusSignCount(N, L, D);
  cout << "Expected: " << expected << ", Got: " << result << "\n\n\n";

  N = 8;
  L = {1, 2, 2, 1, 1, 2, 2, 1};
  D = "UDUDLRLR";
  expected = 1;
  result = getPlusSignCount(N, L, D);
  cout << "Expected: " << expected << ", Got: " << result << "\n\n\n";

  return 0;
}

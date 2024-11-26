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

class IntervalSet {
private:
  set<Interval, CompareByAnchorStart> intervals;

public:
  void insert(Interval newInterval) {
    auto it = intervals.lower_bound(newInterval);

    // Check previous interval for overlap
    if (it != intervals.begin()) {
      auto prevIt = std::prev(it);
      if (prevIt->a == newInterval.a && *prevIt == newInterval) {
        newInterval = prevIt->merge(newInterval);
        intervals.erase(prevIt);
      }
    }

    // Check next intervals for overlap
    while (it != intervals.end() && it->a == newInterval.a &&
           *it == newInterval) {
      newInterval = newInterval.merge(*it);
      it = intervals.erase(it);
    }

    intervals.insert(newInterval);
  }

  const set<Interval, CompareByAnchorStart> &getIntervals() const {
    return intervals;
  }
};

class IntervalSetByStart {
private:
  set<Interval, CompareByStartAnchor> intervals;

public:
  void insert(Interval newInterval) {
    auto it = intervals.lower_bound(newInterval);

    // Check previous interval for overlap
    if (it != intervals.begin()) {
      auto prevIt = std::prev(it);
      if (prevIt->a == newInterval.a && *prevIt == newInterval) {
        newInterval = prevIt->merge(newInterval);
        intervals.erase(prevIt);
      }
    }

    // Check next intervals for overlap
    while (it != intervals.end() && it->a == newInterval.a &&
           *it == newInterval) {
      newInterval = newInterval.merge(*it);
      it = intervals.erase(it);
    }

    intervals.insert(newInterval);
  }

  const set<Interval, CompareByStartAnchor> &getIntervals() const {
    return intervals;
  }
};

long long getPlusSignCount(int N, vector<int> L, string D) {
  long long x = 0, y = 0, m = 0;
  IntervalSet hlines;
  IntervalSetByStart vlines;

  for (int i = 0; i < N; i++) {
    m += L[i];
    if (i + 1 < N && D[i + 1] == D[i])
      continue;

    switch (D[i]) {
    case 'U':
      vlines.insert(Interval(x, y, y + m));
      y += m;
      break;
    case 'D':
      vlines.insert(Interval(x, y - m, y));
      y -= m;
      break;
    case 'L':
      hlines.insert(Interval(y, x - m, x));
      x -= m;
      break;
    case 'R':
      hlines.insert(Interval(y, x, x + m));
      x += m;
      break;
    }
    m = 0;
  }

  long long nplus = 0;
  auto hline_it = hlines.getIntervals().begin();
  for (const Interval &vline : vlines.getIntervals()) {
    while (hline_it != hlines.getIntervals().end() && hline_it->a <= vline.s) {
      hline_it++;
    }

    auto current_h = hline_it;
    while (current_h != hlines.getIntervals().end() && current_h->a < vline.e) {
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

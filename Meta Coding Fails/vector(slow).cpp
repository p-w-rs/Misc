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

inline void merge_intervals(vector<Interval> &intervals,
                            vector<Interval> &result) {
  if (intervals.empty())
    return;

  Interval current = intervals[0];
  for (size_t i = 1; i < intervals.size(); i++) {
    if (intervals[i] == current) {
      current = current.merge(intervals[i]);
    } else {
      if (current.a != 0 || current.s != 0 || current.e != 0) {
        result.push_back(current);
      }
      current = intervals[i];
    }
  }
  if (current.a != 0 || current.s != 0 || current.e != 0) {
    result.push_back(current);
  }
}

long long getPlusSignCount(int N, vector<int> L, string D) {
  long long x = 0, y = 0, m = 0;
  vector<Interval> vstrokes, hstrokes, vlines, hlines;
  vstrokes.reserve(N);
  vlines.reserve(N);
  hstrokes.reserve(N);

  for (int i = 0; i < N; i++) {
    m += L[i];
    if (i + 1 < N && D[i + 1] == D[i])
      continue;

    switch (D[i]) {
    case 'U':
      vstrokes.emplace_back(Interval(x, y, y + m));
      y += m;
      break;
    case 'D':
      vstrokes.emplace_back(Interval(x, y - m, y));
      y -= m;
      break;
    case 'L':
      hstrokes.emplace_back(Interval(y, x - m, x));
      x -= m;
      break;
    case 'R':
      hstrokes.emplace_back(Interval(y, x, x + m));
      x += m;
      break;
    }
    m = 0;
  }
  sort(hstrokes.begin(), hstrokes.end(),
       [](const Interval &lhs, const Interval &rhs) {
         if (lhs.a != rhs.a)
           return lhs.a < rhs.a;
         return lhs.s < rhs.s;
       });
  merge_intervals(hstrokes, hlines);

  sort(vstrokes.begin(), vstrokes.end(),
       [](const Interval &lhs, const Interval &rhs) {
         if (lhs.a != rhs.a)
           return lhs.a < rhs.a;
         return lhs.s < rhs.s;
       });
  merge_intervals(vstrokes, vlines);
  sort(vlines.begin(), vlines.end(),
       [](const Interval &lhs, const Interval &rhs) {
         if (lhs.s != rhs.s)
           return lhs.s < rhs.s;
         return lhs.a < rhs.a;
       });

  long long nplus = 0;
  long long h_idx = 0;
  const long long h_size = hlines.size();
  for (const Interval &vline : vlines) {
    // Advance iterator to first potentially intersecting horizontal line
    while (h_idx < h_size && hlines[h_idx].a <= vline.s) {
      h_idx++;
    }

    // Check all horizontal lines that could intersect with current vertical
    for (long long i = h_idx; i < h_size && hlines[i].a < vline.e; i++) {
      if (hlines[i].s < vline.a && vline.a < hlines[i].e) {
        nplus++;
      }
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

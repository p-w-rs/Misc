#include <iostream>
#include <iterator>
#include <map>
#include <string>
#include <unordered_map>
#include <vector>

using namespace std;

struct Interval {
  long long a, s, e;

  Interval() : a(0), s(0), e(0) {}
  Interval(long long a_, long long s_, long long e_) : a(a_), s(s_), e(e_) {}

  Interval merge(const Interval &other) const {
    return a == other.a && !(s > other.e || other.s > e)
               ? Interval(a, min(s, other.s), max(e, other.e))
               : Interval(a, s, e);
  }

  void print() const { cout << "(" << a << "," << s << "," << e << ") "; }
};

long long getPlusSignCount(int N, vector<int> L, string D) {
  long long x = 0, y = 0, m = 0;
  vector<Interval> vstrokes, hstrokes;
  hstrokes.reserve(N);
  vstrokes.reserve(N);

  // O(N) to create vertical and horizontal strokes
  char prev_d = ' ';
  for (int i = 0; i < N; i++) {
    if (D[i] == 'U') {
      m = y + L[i];
      if (prev_d == 'U' || prev_d == 'D') {
        Interval &vstroke = vstrokes.back();
        vstroke.s = min(m, vstroke.s);
        vstroke.e = max(m, vstroke.e);
      } else {
        vstrokes.emplace_back(Interval(x, y, m));
      }
      y = m;
    } else if (D[i] == 'D') {
      m = y - L[i];
      if (prev_d == 'U' || prev_d == 'D') {
        Interval &vstroke = vstrokes.back();
        vstroke.s = min(m, vstroke.s);
        vstroke.e = max(m, vstroke.e);
      } else {
        vstrokes.emplace_back(Interval(x, m, y));
      }
      y = m;
    } else if (D[i] == 'L') {
      m = x - L[i];
      if (prev_d == 'L' || prev_d == 'R') {
        Interval &hstroke = hstrokes.back();
        hstroke.s = min(m, hstroke.s);
        hstroke.e = max(m, hstroke.e);
      } else {
        hstrokes.emplace_back(Interval(y, m, x));
      }
      x = m;
    } else if (D[i] == 'R') {
      m = x + L[i];
      if (prev_d == 'L' || prev_d == 'R') {
        Interval &hstroke = hstrokes.back();
        hstroke.s = min(m, hstroke.s);
        hstroke.e = max(m, hstroke.e);
      } else {
        hstrokes.emplace_back(Interval(y, x, m));
      }
      x = m;
    }
    prev_d = D[i];
  }

  // O(H log H) to sort vertical and horizontal strokes
  sort(hstrokes.begin(), hstrokes.end(),
       [](const Interval &lhs, const Interval &rhs) {
         if (lhs.a != rhs.a)
           return lhs.a < rhs.a;
         return lhs.s < rhs.s;
       });

  // O(V log V) to sort vertical strokes
  sort(vstrokes.begin(), vstrokes.end(),
       [](const Interval &lhs, const Interval &rhs) {
         if (lhs.s != rhs.s)
           return lhs.s < rhs.s;
         return lhs.a < rhs.a;
       });

  long long nplus = 0;
  long long h_idx = 0;
  const long long h_size = hstrokes.size();
  unordered_map<long long, Interval> prev_v;
  unordered_map<long long, Interval> prev_h;

  // Worst case O(V*H) to count number of plus signs
  for (long long i = 0; i < vstrokes.size(); i++) {
    Interval vstroke = vstrokes[i];
    // O(1) to merge overlapping vertical strokes
    if (prev_v.find(vstroke.a) != prev_v.end()) {
      vstroke = vstroke.merge(prev_v[vstroke.a]);
    }
    prev_v[vstroke.a] = vstroke;

    // Set of h reduce over time
    while (h_idx < h_size && hstrokes[h_idx].a <= vstroke.s) {
      h_idx++;
    }
    // Worst case O(H) to count number of plus signs
    for (long long j = h_idx; j < h_size && hstrokes[j].a < vstroke.e; j++) {
      Interval hstroke = hstrokes[j];
      if (prev_h.find(hstroke.a) != prev_h.end()) {
        hstroke = hstroke.merge(prev_h[hstroke.a]);
      }
      prev_h[hstroke.a] = hstroke;

      if (hstroke.s < vstroke.a && vstroke.a < hstroke.e) {
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

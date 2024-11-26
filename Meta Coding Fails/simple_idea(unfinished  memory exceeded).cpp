#include <iostream>
#include <iterator>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

using namespace std;

// Custom struct for coordinates
struct Coord {
  long long x, y;

  bool operator==(const Coord &other) const {
    return x == other.x && y == other.y;
  }
};

// Hash function for Coord
namespace std {
template <> struct hash<Coord> {
  size_t operator()(const Coord &coord) const {
    return hash<long long>()(coord.x) ^ (hash<long long>()(coord.y) << 1);
  }
};
} // namespace std

long long getPlusSignCount(int N, vector<int> L, string D) {
  long long nplus, x, y, j = 0;
  unordered_map<Coord, bool> vertical_stroke_coords;
  unordered_map<Coord, bool> horizontal_stroke_coords;
  unordered_set<Coord> plus_sign_coords;

  char prev_dir = ' ';
  for (int i = 0; i < N; i++) {
    switch (D[i]) {
    case 'U':
      if (prev_dir == 'L' || prev_dir == 'R')
        vertical_stroke_coords[Coord{x, y}] = true;
      for (j = 0; j < L[i]; j++)
        vertical_stroke_coords[Coord{x, ++y}] = true;
      break;
    case 'D':
      if (prev_dir == 'L' || prev_dir == 'R')
        vertical_stroke_coords[Coord{x, y}] = true;
      for (j = 0; j < L[i]; j++)
        vertical_stroke_coords[Coord{x, --y}] = true;
      break;
    case 'L':
      if (prev_dir == 'U' || prev_dir == 'D')
        horizontal_stroke_coords[Coord{x, y}] = true;
      for (j = 0; j < L[i]; j++)
        horizontal_stroke_coords[Coord{--x, y}] = true;
      break;
    case 'R':
      if (prev_dir == 'U' || prev_dir == 'D')
        horizontal_stroke_coords[Coord{x, y}] = true;
      for (j = 0; j < L[i]; j++)
        horizontal_stroke_coords[Coord{++x, y}] = true;
      break;
    }
    prev_dir = D[i];
  }
  long long nplus;
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

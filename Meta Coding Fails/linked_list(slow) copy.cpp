#include <iostream>
#include <iterator>
#include <map>
#include <stdio.h>
#include <string>
#include <unordered_map>
#include <vector>

using namespace std;

struct Node {
  long long s;
  long long e;
  Node *next;
};
// Calculate proper alignment for Node struct
constexpr size_t NODE_ALIGN = alignof(Node);
// Round up the size to ensure proper alignment
constexpr size_t NODE_SIZE =
    (sizeof(Node) + NODE_ALIGN - 1) & ~(NODE_ALIGN - 1);
// Aligned memory array
alignas(Node) static char memory[NODE_SIZE * 2000000];
static size_t midx = 0;        // memory index
static size_t inc = NODE_SIZE; // memory increment

// Helper to get aligned pointer to new node
Node *getNode() {
  Node *node = reinterpret_cast<Node *>(memory + midx);
  midx += inc;
  return node;
}

Node *insert(Node *head, long long s, long long e) {
  Node *new_node = getNode();
  new_node->s = s;
  new_node->e = e;
  new_node->next = nullptr;

  // Empty list case
  if (!head) {
    return new_node;
  }

  // Find insertion point
  Node *prev = nullptr;
  Node *curr = head;
  while (curr && curr->s < s) {
    prev = curr;
    curr = curr->next;
  }

  // Insert the new node
  if (!prev) {
    new_node->next = head;
    head = new_node;
  } else {
    prev->next = new_node;
    new_node->next = curr;
  }

  // Merge overlapping intervals
  if (prev) {
    if (prev->e >= new_node->s) {
      prev->e = max(prev->e, new_node->e);
      prev->next = new_node->next;
      new_node = prev;
    }
  }

  Node *start = new_node;
  while (start && start->next) {
    // Check if current interval overlaps with next
    if (start->e >= start->next->s) {
      // Merge the intervals
      start->e = max(start->e, start->next->e);
      // Skip the merged node
      start->next = start->next->next;
    } else {
      break;
    }
  }
  return head;
}

long long getPlusSignCount(int N, vector<int> L, string D) {
  memset(memory, 0, sizeof(memory));
  long long x = 0, y = 0;
  long long nplus = 0;
  map<long long, Node *> vlines;
  unordered_map<long long, Node *> hlines;

  long long m = 0;
  for (int i = 0; i < N; i++) {
    m += L[i];
    if (i + 1 < N && D[i + 1] == D[i])
      continue;

    switch (D[i]) {
    case 'U':
      vlines[x] = insert(vlines[x], y, y + m);
      y += m;
      break;
    case 'D':
      vlines[x] = insert(vlines[x], y - m, y);
      y -= m;
      break;
    case 'L':
      hlines[y] = insert(hlines[y], x - m, x);
      x -= m;
      break;
    case 'R':
      hlines[y] = insert(hlines[y], x, x + m);
      x += m;
      break;
    }
    m = 0;
  }

  Node *v, *h;
  long long x1, x2, y1, y2;
  for (const auto &[y, hhead] : hlines) {
    h = hhead;
    while (h) {
      x1 = h->s, x2 = h->e;
      auto px1 = vlines.lower_bound(x1), px2 = vlines.upper_bound(x2);
      for (auto it = px1; it != px2; ++it) {
        const auto &[x, vhead] = *it;
        if (x <= x1 || x >= x2)
          continue;
        v = vhead;
        while (v) {
          y1 = v->s, y2 = v->e;
          if (y1 < y && y < y2) {
            nplus++;
            break;
          }
          v = v->next;
        }
      }
      h = h->next;
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
  cout << "Expected: " << expected << ", Got: " << result << endl;

  N = 8;
  L = {1, 1, 1, 1, 1, 1, 1, 1};
  D = "RDLUULDR";
  expected = 1;
  result = getPlusSignCount(N, L, D);
  cout << "Expected: " << expected << ", Got: " << result << endl;

  N = 8;
  L = {1, 2, 2, 1, 1, 2, 2, 1};
  D = "UDUDLRLR";
  expected = 1;
  result = getPlusSignCount(N, L, D);
  cout << "Expected: " << expected << ", Got: " << result << endl;

  return 0;
}

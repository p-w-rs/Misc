# A program to deterime some costs associated with creating a farm via the desert farm act

# The total amout of land claimable by a single person is 320 acres
total_land = 320 # acres
required_irrigation = 1 / 8 # ratio

acre = 43560 # square feet
irrigated = total_land * required_irrigation * acre # square feet
tree = π * 12.5^2 # square feet

# The total number of trees that can be planted on the land
total_trees = irrigated / tree
total_pipe = (total_trees * 25) * 2 # feet

# Costs
tree_cost = total_trees * 35
pipe_cost = (total_pipe / 500) * 124.95

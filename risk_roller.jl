function risk_battle_simulation(red, blue)
    while red > 0 && blue > 0
        red_roll = sort(rand(1:6, min(3, red)), rev=true)
        blue_roll = sort(rand(1:6, min(2, blue)), rev=true)

        battle_size = min(length(red_roll), length(blue_roll))

        for i in 1:battle_size
            if blue_roll[i] >= red_roll[i]
                red -= 1
            else
                blue -= 1
            end
        end
    end
    return red, blue
end
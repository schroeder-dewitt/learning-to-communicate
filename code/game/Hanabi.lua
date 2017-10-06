require 'torch'
local class = require 'class'

local log = require 'include.log'
local kwargs = require 'include.kwargs'
local util = require 'include.util'


local Hanabi = class('Hanabi')

function shuffle(t)
   local size = #t
   for i = size, 2, -1 do
      local j = math.random(i)
      t[i], t[j] = t[j], t[i]
   end
end

function insert_after_known(player, card)
   local index = 1
   table.insert(player, index, card)
end

-- Lower level print fn
function print_cards(t, hand, prefix, discard)
   local count = 0
   if (prefix ~= nil) then
      io.write(string.format("\27[37m%s ", prefix))
   end

   if (discard == nil) then
      for k, v in ipairs(t) do
         count = count + 1
         if (hand ~= 1) then
            io.write(string.format("\27[37m%d\t", count))
         end
         if (v["col"] == "R") then
            io.write(string.format("\27[31m%d ", v["val"]))
         elseif (v["col"] == "G") then
            io.write(string.format("\27[32m%d ", v["val"]))
         elseif (v["col"] == "B") then
            io.write(string.format("\27[34m%d ", v["val"]))
         elseif (v["col"] == "Y") then
            io.write(string.format("\27[33m%d ", v["val"]))
         else
            io.write(string.format("\27[37m%d ", v["val"]))
         end
         if (hand ~= 1) then
            io.write("\n")
         end
      end
   else
      local colors = {"R", "G", "B", "Y", "W"}
      for i, color in ipairs(colors) do
         for k, v in ipairs(t[color]) do
            count = count + 1
            if (hand ~= 1) then
               io.write(string.format("\27[37m%d\t", count))
            end
            if (v["col"] == "R") then
               io.write(string.format("\27[31m%d ", v["val"]))
            elseif (v["col"] == "G") then
               io.write(string.format("\27[32m%d ", v["val"]))
            elseif (v["col"] == "B") then
               io.write(string.format("\27[34m%d ", v["val"]))
            elseif (v["col"] == "Y") then
               io.write(string.format("\27[33m%d ", v["val"]))
            else
               io.write(string.format("\27[37m%d ", v["val"]))
            end
            if (hand ~= 1) then
               io.write("\n")
            end
         end
      end
   end
   io.write("\n")
end

-- Complete status print fn
function print_all(player1, player2, played)
   print()
   print_cards(player1, 1, "Player 1:")
   print_cards(player2, 1, "Player 2:")
   print_cards(played, 1,  "Table:   ")
   print_cards(played.discard, 1, "Discard: ", 1)
   io.write(string.format("\27[37mInfo tokens: %d, Num lives: %d\n", played["info_tokens"], played["num_lives"]))
end

-- Try play
function Hanabi:try_play(played, card)
   -- Order of played is R, G, B, Y, W
   if card then
     if (card.col == "R") then
        if (card.val == played[1].val + 1) then played[1] = card else self:add_discard(played.discard, card); played.num_lives = played.num_lives - 1 end
     elseif (card.col == "G") then
        if (card.val == played[2].val + 1) then played[2] = card else self:add_discard(played.discard, card); played.num_lives = played.num_lives - 1 end
     elseif (card.col == "B") then
        if (card.val == played[3].val + 1) then played[3] = card else self:add_discard(played.discard, card); played.num_lives = played.num_lives - 1 end
     elseif (card.col == "Y") then
        if (card.val == played[4].val + 1) then played[4] = card else self:add_discard(played.discard, card); played.num_lives = played.num_lives - 1 end
     else
        if (card.val == played[5].val + 1) then played[5] = card else self:add_discard(played.discard, card); played.num_lives = played.num_lives - 1 end
     end
   end
end

-- Add to sorted discard pile
function Hanabi:add_discard(discard, new)
   local index = 1
   self.discard_card = new
   if new then
     for i = 1, #discard[new.col] do
        if (new.val < discard[new.col][i].val) then
           index = i
           break
        else
           index = i + 1
        end
     end
     table.insert(discard[new.col], index, new)
   end
end

-- Action
function Hanabi:action(player1, player2, played, cards, move, bot_on)
   -- Discard
   local letter = string.match(move, "%D")
   local number = tonumber(string.match(move, "%d+"))
   self.discard_card = nil
   if (letter == "D") then
      if (number == nil or number < 1 or number > 5) then return 0 end
      self:add_discard(played.discard, table.remove(player1, number))
      insert_after_known(player1, table.remove(cards, 1))
      if (played["info_tokens"] < 8) then
         played["info_tokens"] = played["info_tokens"] + 1
      end
      return 1
   elseif (letter == "P") then
      if (number == nil or number < 1 or number > 5) then return 0 end
      self:try_play(played, table.remove(player1, number))
      insert_after_known(player1, table.remove(cards, 1))
      return 1
   elseif (letter == "I") then
      if (played["info_tokens"] > 0) then
         played["info_tokens"] = played["info_tokens"] - 1
         return 1
      else
         return 0
      end
   else
      return 0
   end
end

function Hanabi:__init(opt)
    local opt_game = kwargs(_, {
        { 'game_action_space', type = 'int-pos', default = 2 },
        { 'game_reward_shift', type = 'int', default = 0 },
        { 'game_comm_bits', type = 'int', default = 0 },
        { 'game_comm_sigma', type = 'number', default = 2 },
        { 'game_num_nums', type = 'number', default = 5 },
        { 'game_num_cols', type = 'number', default = 5 },
        { 'game_cheat', type = 'number', default = 0 },
        { 'debug', type = 'number', default = 0 },
    })

    -- Steps max override
    -- opt.nsteps = 4 * opt.game_nagents - 6

    for k, v in pairs(opt_game) do
        if not opt[k] then
            opt[k] = v
        end
    end
    self.opt = opt

    -- Rewards
    self.reward_all_live = 1 + self.opt.game_reward_shift
    self.reward_all_die = -1 + self.opt.game_reward_shift

    -- set a random seed for random deck?
    math.randomseed(os.time())

    -- Spawn new game
    self:reset()
end

function Hanabi:reset()
-------------------------
-- Game setup
-------------------------

-- First populate the card deck
    local colors_all = {"R", "G", "B", "Y", "W"}
    self.colors = {}
    self.random = torch.zeros(self.opt.bs, self.opt.game_nagents)
    self.extra_cards = torch.zeros(self.opt.bs)
    for i = 1, self.opt.game_num_cols do
       self.colors[i] = colors_all[i]
    end
    local repeats = {3, 2, 2, 2, 1}
    self.games = {}
    local games = self.games
    games['cards'] = {}
    games['player1'] = {}
    games['player2'] = {}
    games['played'] = {}
    self.last_action = {}
    self.finished = torch.zeros(self.opt.bs, self.opt.game_num_cols)
    for b = 1, self.opt.bs do
       games['cards'][b] = {} 
       games['player1'][b] = {}
       games['player2'][b] = {}
       games['played'][b] = {}
       local cards = games['cards'][b]

       for i = 1, self.opt.game_num_nums do
          for k, v in ipairs(self.colors) do
             for j = 1, repeats[i] do
                a_card = {}
                a_card["val"] = i
                a_card["col"] = v
                table.insert(cards, 1, a_card)
             end
          end
       end

       -- Shuffle
       shuffle(cards)

       -- Deal out cards
       local player1 = games['player1'][b]
       local player2 = games['player2'][b]
       local played = games['played'][b]
       played.discard = {}
       played.discard["R"] = {}
       played.discard["G"] = {}
       played.discard["B"] = {}
       played.discard["Y"] = {}
       played.discard["W"] = {}
       for i = 1, 5 do
          table.insert(player1, 1, table.remove(cards, 1))
          table.insert(player2, 1, table.remove(cards, 1))
       end
       for i = 1, self.opt.game_num_cols do
          local card = {}
          card.val = 0
          card.col = self.colors[i]
          table.insert(played, i, card)
       end
       -- print(player1[1])
       if self.opt.debug == 1 and b == 1 then 
           print_cards(cards)
        end
       games['played'][b]["info_tokens"] = 8 -- start out with 8 info tokens
       games['played'][b]["num_lives"] = 3 -- start out with 4 fuse tokens, but when last is reached, game over!
       self.last_action[b] = 'none'
    end

    -- Reset rewards
    self.reward = torch.zeros(self.opt.bs, self.opt.game_nagents)

    -- Reached end
    self.terminal = torch.zeros(self.opt.bs)

    -- Step counter
    self.step_counter = 1

    -- Who is in
    self.active_agent = torch.zeros(self.opt.bs, self.opt.nsteps)
    for b = 1, self.opt.bs do
        for step = 1, self.opt.nsteps do
            local id = step % 2 + 1
            self.active_agent[{ { b }, { step } }] = id
        end
    end
    return self
end

function Hanabi:getActionRange(step, agent, b)
    local range = {}

    if self.opt.model_dial == 1 then
        for i = 1, self.opt.bs do
            if (self.games['played'][i]["info_tokens"] == 0) then
               bound = 10
            else
               bound = self.opt.game_action_space - 1
            end

            if self.active_agent[i][step] == agent then
                range[i] = { { i }, { 1, bound } }
            else
                range[i] = { { i }, { self.opt.game_action_space } }
            end
        end
        return range
    else
        local comm_range = {}
        for i = 1, self.opt.bs do
            if self.active_agent[i][step] == agent then
                range[i] = { { i }, { 1, self.opt.game_action_space } }
                comm_range[i] = { { i }, { self.opt.game_action_space + 1, self.opt.game_action_space_total } }
            else
                range[i] = { { i }, { 1 } }
                comm_range[i] = { { i }, { 0, 0 } }
            end
        end
        return range, comm_range
    end
end

--[[
function Hanabi:getReward(a_t)

    for b = 1, self.opt.bs do
        local active_agent = self.active_agent[b][self.step_counter]
        if (a_t[b][active_agent] == 2 and self.terminal[b] == 0) then
            local has_been = self.has_been[{ { b }, { 1, self.step_counter }, {} }]:sum(2):squeeze(2):gt(0):float():sum()
            if has_been == self.opt.game_nagents then
                self.reward[b] = self.reward_all_live
            else
                self.reward[b] = self.reward_all_die
            end
            self.terminal[b] = 1
        elseif self.step_counter == self.opt.nsteps and self.terminal[b] == 0 then
            self.terminal[b] = 1
        end
    end

    return self.reward:clone(), self.terminal:clone()
end
--]]

function Hanabi:step(a_t)
    local action_lookup = {'P1', 'P2', 'P3', 'P4', 'P5', 'D1', 'D2', 'D3', 'D4', 'D5'}
    for i = 1, self.opt.game_num_nums do
      table.insert(action_lookup, #action_lookup+1, 'I'..i)
    end
    for i = 1, self.opt.game_num_cols do
      table.insert(action_lookup, #action_lookup+1, 'I'..self.colors[i])
    end

    local games = self.games
    local prev_played 
   for b = 1, self.opt.bs do 
       self.reward[b] = 0
       if self.terminal[b] == 0 then
           local player1 = games['player1'][b]
           local player2 = games['player2'][b]
           local played = games['played'][b]
           prev_played = util.dc(played)
           
           local cards = games['cards'][b]
           local bot_on = 0 -- Turn bot ON and OFF!
           if self.opt.debug == 1 and b == 1 then 
             print_all(player1, player2, played)
           end
           local answer
           if self.active_agent[b][self.step_counter] == 1 then
                answer = action_lookup[a_t[b][1]]
                if self.opt.debug == 1 and b == 1 then 
                   print("Player1 Action: "..answer)
                end
                self:action(player1, player2, played, cards, answer, bot_on)
           else
                answer = action_lookup[a_t[b][2]]
                if self.opt.debug == 1 and b == 1 then 
                   print("Player2 Action: "..answer)
                end
                self:action(player2, player1, played, cards, answer, bot_on)
           end
           total_played = 0
           for i = 1, self.opt.game_num_cols do
               self.reward[b]  = self.reward[b] + (played[i].val - prev_played[i].val)
               total_played = played[i].val + total_played
               if self.finished[b][i] == 0 and played[i].val ==  self.opt.game_num_cards then
                   self.finished[b][i] = 1
                   played.info_tokens = math.min( played.info_tokens + 1, 8 )
               end
           end
          -- self.reward[b] = self.reward[b] - (prev_played["num_lives"] - played["num_lives"])
           self.last_action[b] = answer
           winning = total_played == self.opt.game_num_cols*self.opt.game_num_nums
           if winning then
              print('FULL POINTS!!!!!')
           end
           if( winning or self.extra_cards[b] == 2 or played["num_lives"]  == 0 or  self.step_counter == self.opt.nsteps ) then
                self.terminal[b] = 1
           end
           if (#cards == 0) then
              self.extra_cards[b] = self.extra_cards[b] + 1
           end
        end
    end
    -- Get rewards
    -- local reward, terminal = self:getReward(a_t)

    -- Make step
    self.step_counter = self.step_counter + 1

    return self.reward:clone(), self.terminal:clone()
end

function Hanabi:getCommLimited(step, i)
    if self.opt.game_comm_limited then

        local range = {}

        -- Get range per batch
        for b = 1, self.opt.bs do
            -- if agent is active read from field of previous agent
            if step > 1 and i == self.active_agent[b][step] then
                range[b] = { self.active_agent[b][step - 1], {} }
            else
                range[b] = 0
            end
        end
        return range
    else
        return nil
    end
end

function Hanabi:setRandom(random)
  self.random =  util.dc(random)
end

function Hanabi:getState()
    local state = {}
    local colors = {}
    colors['R'] = 1
    colors['G'] = 2 
    colors['B' ] = 3
    colors['Y' ] = 4
    colors['W' ] = 5

    for agent = 1, self.opt.game_nagents do

        state[agent] = torch.Tensor(self.opt.bs, self.opt.model_input_size):zero()

    end
    local games = self.games
    for b = 1, self.opt.bs do
       local player1 = games['player1'][b]
       local player2 = games['player2'][b]
       local player_array = { player2, player1}
       local played = games['played'][b]
         for agent = 1, self.opt.game_nagents do
            local observed_cards = player_array[agent]
            for card = 1, #observed_cards do
              if observed_cards[card] then
                state[agent][b][card] = observed_cards[card].val
                state[agent][b][card + 5] = colors[observed_cards[card].col]
              end
                -- Represent cards with 1-25
                -- state[agent][b][card] = observed_cards[card].val + self.opt.game_num_nums*(colors[observed_cards[card].col]-1)
            end

            if (self.opt.game_cheat == 1) then
               -- Cheat!! see your own cards
               observed_cards = player_array[agent%2+1]
               for card = 1, #observed_cards do
                   state[agent][b][card + 10] = observed_cards[card].val
                   state[agent][b][card + 15] = colors[observed_cards[card].col]
                   -- Represent cards with 1-25
                   -- state[agent][b][card + 5] = observed_cards[card].val + self.opt.game_num_nums*(colors[observed_cards[card].col]-1)
               end
            else
               -- Don't cheat. Use hints
               if self.active_agent[b][self.step_counter] ~= agent then
                   local my_cards = player_array[(agent) % 2 + 1]
                   for card = 1, #my_cards do
                       if my_cards[card] then
                         local test_color = 'I'..my_cards[card].col
                         local test_value = 'I'..my_cards[card].val
                         if test_color == self.last_action[b] then
                             state[agent][b][card + 10] = colors[my_cards[card].col]
                             -- print('worked', agent)
                         elseif test_value == self.last_action[b] then
                             state[agent][b][card + 15] = my_cards[card].val
                             -- print('worked2', agent)
                         end
                         -- print(self.last_action[b])
                      end
                   end
               end
            end
            for c = 1,self.opt.game_num_cols do
                state[agent][b][20 + c]  = played[c].val
            end
            if self.discard_card then
               state[agent][b][26] = colors[self.discard_card.col]
               state[agent][b][27] = self.discard_card.val
            end

            state[agent][b][28] = played.num_lives + self.random[b][agent%2+1]*3
            state[agent][b][29] = played.info_tokens
            state[agent][b][30] = self.extra_cards[b]
        end
    end

    return state
end

return Hanabi


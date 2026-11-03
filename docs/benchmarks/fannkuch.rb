n = 10
perm1 = (0...n).to_a; count = [0] * n; r = n; checksum = 0; maxflips = 0; turn = 0
loop do
  while r != 1
    count[r - 1] = r; r -= 1
  end
  perm = perm1.dup; flips = 0
  while (k = perm[0]) != 0
    i = 0; j = k
    while i < j
      perm[i], perm[j] = perm[j], perm[i]; i += 1; j -= 1
    end
    flips += 1
  end
  maxflips = flips if flips > maxflips
  checksum += turn.even? ? flips : -flips
  loop do
    if r == n
      puts checksum; puts "Pfannkuchen(#{n}) = #{maxflips}"; exit
    end
    first = perm1[0]
    r.times { |i| perm1[i] = perm1[i + 1] }
    perm1[r] = first
    count[r] -= 1
    break if count[r] > 0
    r += 1
  end
  turn += 1
end

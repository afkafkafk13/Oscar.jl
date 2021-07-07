# Detinko, Flannery, O'Brien "Recognizing finite matrix groups over infinite
# fields", Section 4.2
function isomorphic_group_over_finite_field(matrices::Vector{T}) where T <: Union{ fmpq_mat, AbstractAlgebra.MatElem{nf_elem} }
   @assert !isempty(matrices)

   # One should probably check whether all matrices are n by n (and invertible
   # and such ...)

   K = base_ring(matrices[1])
   n = nrows(matrices[1])

   Fq, matrices_Fq = good_reduction(matrices, 2)

   G = MatrixGroup(n, Fq, matrices_Fq)
   N = GAP.Globals.Order(G.X)
   if maximal_order_of_finite_linear_group_qq(degree(K)*n) < N
      error("Group is not finite")
   end

   G_to_fin_pres = GAP.Globals.IsomorphismFpGroupByGenerators(G.X, GAP.julia_to_gap([ g.X for g in gens(G) ]))
   F = GAP.Globals.Range(G_to_fin_pres)
   rels = GAP.Globals.RelatorsOfFpGroup(F)

   inv_matrices = Vector{T}(undef, length(matrices))
   inv_computed = falses(length(matrices))
   for i = 1:length(rels)
      rel = map(Int, GAP.Globals.LetterRepAssocWord(rels[i]))
      M = identity_matrix(K, n)
      for k in rel
         if k < 0
            k = -k
            if !inv_computed[k]
               inv_matrices[k] = inv(matrices[k])
            end
            M *= inv_matrices[k]
         else
            M *= matrices[k]
         end
      end
      if !isone(M)
         error("Group is not finite")
      end
   end
   return G
end

function good_reduction(matrices::Vector{T}, start::Int = 2) where T <: Union{ fmpq_mat, AbstractAlgebra.MatElem{nf_elem} }
   p = next_prime(start)
   b, Fq, matrices_Fq = test_modulus(matrices, p)
   while !b
      p = next_prime(p)
      b, Fq, matrices_Fq = test_modulus(matrices, p)
   end
   return Fq, matrices_Fq
end

# Detinko, Flannery, O'Brien "Recognizing finite matrix  groups over infinite
# fields", Section 3.1 claims that any prime != 2 not dividing any denominator
# of the matrices and their inverses (!) works.
function test_modulus(matrices::Vector{fmpq_mat}, p::Int)
   Fp = GF(p)
   matrices_Fp = Vector{AbstractAlgebra.MatElem{elem_type(Fp)}}(undef, length(matrices))
   if p == 2
      return false, Fp, matrices_Fp
   end

   for M in matrices
      for i = 1:nrows(M)
         for j = 1:ncols(M)
            if iszero(M[i, j])
               continue
            end

            if mod(denominator(M[i, j]), p) == 0
               return false, Fp, matrices_Fp
            end
         end
      end
   end
   # I don't want to invert everything in char 0, so I just check whether the
   # matrices are still invertible mod p.
   for i = 1:length(matrices)
      matrices_Fp[i] = map_entries(Fp, matrices[i])
      if rank(matrices_Fp[i]) != nrows(matrices_Fp[i])
         return false, Fp, matrices_Fp
      end
   end

   return true, Fp, matrices_Fp
end

# Detinko, Flannery, O'Brien "Recognizing finite matrix  groups over infinite
# fields", Section 3.2 claims that any prime != 2 not dividing the discriminant
# of the defining polynomial and not dividing any denominator of the matrices
# and their inverses (!) works.
function test_modulus(matrices::Vector{T}, p::Int) where T <: AbstractAlgebra.MatElem{nf_elem}
   @assert length(matrices) != 0
   K = base_ring(matrices[1])
   matrices_Fq = Vector{fq_mat}(undef, length(matrices))
   if p == 2
      return false, FiniteField(fmpz(p), 1, "a")[1], matrices_Fq
   end
   O = EquationOrder(K)
   if mod(discriminant(O), p) == 0
      return false, FiniteField(fmpz(p), 1, "a")[1], matrices_Fq
   end
   for M in matrices
      for i = 1:nrows(M)
         for j = 1:ncols(M)
            if iszero(M[i, j])
               continue
            end

            if mod(denominator(M[i, j]), p) == 0
               return false, FiniteField(fmpz(p), 1, "a")[1], matrices_Fq
            end
         end
      end
   end

   # p is does not divide disc(O), so it's not an index divisor, so we don't
   # have to work in the maximal order here.
   P = prime_ideals_over(O, p)
   Fq, OtoFq = ResidueField(O, P[1])
   # I don't want to invert everything in char 0, so I just check whether the
   # matrices are still invertible mod p.
   for i = 1:length(matrices)
      matrices_Fq[i] = matrix(Fq, [ OtoFq(O(numerator(a)))//OtoFq(O(denominator(a))) for a in matrices[i] ])
      if rank(matrices_Fq[i]) != nrows(matrices_Fq[i])
         return false, Fq, matrices_Fq
      end
   end

   return true, Fq, matrices_Fq
end

# Returns the maximal possible order of a finite subgroup of GL(n, QQ).
# Always return a fmpz, only the orders for n <= 16 would fit into an Int64.
# This relies on results in a preprint "The orders of finite linear groups" by
# W. Feit (1995), possibly published as mathscinet.ams.org/mathscinet-getitem?mr=1484185
# in the "Proceedings of the First Jamaican Conference on Group Theory and its
# Applications", 1996. However, I can't find either paper.
# Geoff Robinson claims to have the preprint and posted the relevant information
# at mathoverflow.net/questions/168292/maximal-order-of-finite-subgroups-of-gln-z .
function maximal_order_of_finite_linear_group_qq(n::Int)
   @assert n >= 0
   if n == 0
      return fmpz(1)
   elseif n == 1
      return fmpz(2)
   elseif n == 2
      return fmpz(12)
   elseif n == 3
      return fmpz(48)
   elseif n == 4
      return fmpz(1152)
   elseif n == 5
      return fmpz(3840)
   elseif n == 6
      return fmpz(103680)
   elseif n == 7
      return fmpz(2903040)
   elseif n == 8
      return fmpz(696729600)
   elseif n == 9
      return fmpz(1393459200)
   elseif n == 10
      return fmpz(8360755200)
   end
   # For n > 10, we can use 2^n*n!
   return fmpz(2)^n*factorial(BigInt(n))
end

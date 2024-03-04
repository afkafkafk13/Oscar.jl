## Warnung: show auf desingMor geht noch nicht!!!
export _desing_curve

#####################################################################################################
# Desingularization morphism: birational map between covered schemes with smooth domain
#####################################################################################################

# Fehlt: NormalizationMorphism fuer Schemata -- muessten wir haben, sobald wir Lipman machen wollen
#
#@attributes mutable struct LipmanStyleSequence{
#    DomainType<:AbsCoveredScheme,
#    CodomainType<:AbsCoveredScheme
#   } <: AbsDesingMor{
#                                 DomainType,
#                                 CodomainType,
#                    }
#  maps::Vector{:<union{BlowupMorphism,NormalizationMorphism}}        # count right to left:
#                                                 # original scheme is codomain of map 1
#  # boolean flags
#  resolves_sing::Bool                            # domain not smooth yet?
#  is_trivial::Bool                               # codomain already smooth?
#
#  # fields for caching, may be filled during computation
#  ex_div::Vector{<:EffectiveCartierDivisor}      # list of exc. divisors arising from individual steps
                                                  # in domain(maps[end])
#
#  # fields for caching to be filled a posteriori (on demand, only if partial_res==false)
#  composed_map::AbsCoveredSchemeMorphism        
#  exceptional_divisor::WeilDivisor          
#
#  function LipmanStyleSequence(maps::Vector{<:AbsCoveredSchemeMorphism})
#    n = length(maps)
#    for i in 1:n-1
#      @assert domain(maps[i]) === codomain(maps[i+1]) "not a sequence of morphisms"
#    end
#    return new{typeof(domain(maps[end])),typeof(codomain(first(maps)))}(maps)
#  end
#end


##################################################################################################
# getters
##################################################################################################
maps(phi::AbsDesingMor) = copy(phi.maps)
last_map(phi::AbsDesingMor) = phi.maps[end]
exceptional_divisor_list(phi::BlowUpSequence) = phi.ex_div  ## derzeit Liste von Eff. Cartier Div.

## do not use!!! (for forwarding and certain emergenies)
function underlying_morphism(phi::AbsDesingMor)
  if !isdefined(phi, :composed_map)
    len=length(maps(phi))
    result=underlying_morphism(maps(phi)[1])
    for i in 2:len
      result = compose(underlying_morphism(maps(phi)[i]), result)
    end
    phi.composed_map = result
  end
  return phi.composed_map
end

##################################################################################################
# setting values in DesingMors -- Watch out: only place with direct access to fields!!!
##################################################################################################
function add_map!(f::AbsDesingMor, phi::BlowupMorphism)
  push!(f.maps, phi)
  ex_div = [strict_transform(phi,E) for E in f.ex_div[1:end]]
  push!(ex_div, Oscar.exceptional_divisor(phi))
  f.ex_div = ex_div
  return f
end

function initialize_blow_up_sequence(phi::BlowupMorphism)
  f = BlowUpSequence([phi])
  f.ex_div = [Oscar.exceptional_divisor(phi)]
  if !is_one(center(phi))
    f.is_trivial = false
  else
    f.is_trivial = true
  end
  f.resolves_sing = false                                # we have no information, wether we are done
                                                         # without further computation
  f.is_embedded = false
  return f
end

function add_map_embedded!(f::AbsDesingMor, phi::BlowupMorphism)
  push!(f.maps, phi)
  ex_div = [strict_transform(phi, E) for E in f.ex_div[1:end]]
  push!(ex_div, Oscar.exceptional_divisor(phi))
  f.ex_div = ex_div
  if f.transform_type == :strict
    X_strict, inc_strict,_ = strict_transform(phi, f.embeddings[end])
    push!(f.embeddings, inc_strict)
  elseif f.transform_type == :weak
    I_trans,b = weak_transform_with_multiplicity(phi, f.controlled_transform)
    push!(f.ex_mult,b)
    f.controlled_transform = I_trans
  else
    I_trans = controlled_transform(phi, f.controlled_transform, f.ex_mult[end])
    f.controlled_transform = I_trans
    push!(f.ex_mult, f.ex_mult[end])
  end
  return f
end

function initialize_embedded_blowup_sequence(phi::BlowupMorphism, inc::CoveredClosedEmbedding)
  f = BlowUpSequence([phi])
  f.ex_div = [Oscar.exceptional_divisor(phi)]
  f.is_embedded = true
  f.transform_type = :strict
  if !is_one(center(phi))
    f.is_trivial = false
    X_strict,inc_strict,_ = strict_transform(phi,inc)
    f.embeddings = [f, inc_strict]
    f.resolves_sing = false                              # we have no information, whether we are done
                                                         # without further computation
  else
    f.is_trivial = true
    f.embeddings = [inc, inc]
    f.resolves_sing = false
  end
  return f
end

function initialize_embedded_blowup_sequence(phi::BlowupMorphism, I::IdealSheaf, b::Int)
  f = BlowUpSequence([phi])
  f.ex_div = [Oscar.exceptional_divisor(phi)]
  f.is_embedded = true
  if !is_one(center(phi))
    f.is_trivial = false
    if b == 0
      I_trans, b = weak_transform_with_multiplicity(phi,I)
      f.transform_type = :weak
    elseif b > 0
      I_trans = controlled_transform(phi, I, b)
      f.transform_type = :controlled
    end
    f.controlled_transform = I_trans                     # CAUTION: b is considered set once and for all
    f.ex_mult = [b]
    f.resolves_sing = false                              # we have no information, whether we are done
                                                         # without further computation
  else
    f.is_trivial = true
    f.controlled_transform = I
    f.transform_type = :weak
    f.ex_mult = [0]
    f.resolves_sing = false
  end
  return f
end


##################################################################################################
# desingularization workers
##################################################################################################
function embedded_desingularization(f::Oscar.CoveredClosedEmbedding; algorithm::Symbol=:BEV)
  I_sl = Oscar.ideal_sheaf_of_singular_locus(domain(f))

  ## trivial case: domain(f) was already smooth
  if is_one(I_sl)
    id_W = identity_blow_up(codomain(f))
    phi = initialize_embedded_blowup_sequence(id_W,f)
    phi.resolves_sing = true
    return phi
  end

  ## I_sl non-empty, we need to do something
  dimX = dim(domain(f))
  if dimX == 1
@show "overriding algorithm for curve case"
    return _desing_emb_curve(f,I_sl)
#  elseif ((dimX == 2) && (algorithm == :CJS))
#    return _desing_CJS(f)
#  elseif (algorithm == :BEV)
#    return _desing_BEV(f)
  end
# here the keyword algorithm ensures that the desired method is called
  error("not implemented yet")
end

function embedded_desingularization(inc::ClosedEmbedding; algorithm::Symbol=:BEV)
  return embedded_desingularization(CoveredClosedEmbedding(inc); algorithm)
end

function CoveredClosedEmbedding(inc::ClosedEmbedding)
  dom = CoveredScheme(domain(inc))
  cod = CoveredScheme(codomain(inc))
  mor_dict = IdDict{AbsAffineScheme, ClosedEmbedding}(dom[1][1] => inc)
  cov_mor = CoveringMorphism(default_covering(dom), default_covering(cod), mor_dict; check=false)
  return CoveredClosedEmbedding(dom, cod, cov_mor; check=false)
end

function desingularization(X::AbsCoveredScheme; algorithm::Symbol=:Lipman)
  I_sl = Oscar.ideal_sheaf_of_singular_locus(X)
  
  ## trivial case: X is already smooth
  if is_one(I_sl)
    id_X = identity_blow_up(X)
    maps = [id_X] 
    return_value = BlowUpSequence(maps)
    return_value.resolves_sing = true
    return_value.is_trivial = true
    return return_value
  end

  ## I_sl non-empty, we need to do something 
# here the keyword algorithm ensures that the desired method is called
  dimX = dim(X)
  if dimX == 1
@show "overriding specified method for curves: use naive method"
    return_value = _desing_curve(X, I_sl)
  end
#  if ((dimX == 2) && (algorithm==:Lipman))
#    error("not implemented yet")
#    return_value = _desing_lipman(X, I_sl)
#    return return_value
#  end
#  if ((dimX == 2) && (algorithm==:Jung))
#    error("not implemented yet")
#    return_value = _desing_jung(X)
#   end       
  error("not implemented yet")    
end

function desingularization(X::AbsAffineScheme; algorithm::Symbol=:BEV)
  return desingularization(CoveredScheme(X); algorithm)
end

function _desing_curve(X::AbsCoveredScheme, I_sl::IdealSheaf)
  ## note: I_sl not unit_ideal_sheaf, because this has been caught before in desingularization(X) 
  decomp = Oscar.maximal_associated_points(I_sl)
  I = small_generating_set(pop!(decomp))
  current_blow_up = blow_up(I)
  phi = initialize_blow_up_sequence(current_blow_up)
  decomp = [strict_transform(current_blow_up,J) for J in decomp]
  
  I_sl_temp = I_sl
  while !is_one(I_sl_temp)
    while length(decomp) > 0
      I = small_generating_set(pop!(decomp))
      phi = _do_blow_up(phi,I)
      if length(decomp)>0 
        decomp = [strict_transform(last_map(phi),J) for J in decomp]
      end
    end
    I_sl_temp = Oscar.ideal_sheaf_of_singular_locus(domain(last_map(phi)))
    decomp = Oscar.maximal_associated_points(I_sl_temp)
  end

  phi.resolves_sing = true
  return(phi)
end

function _desing_emb_curve(f::CoveredClosedEmbedding, I_sl::IdealSheaf)
  ## note: I_sl not unit_ideal_sheaf, because this has been caught before in embedded_desingularization(f)
  decomp = Oscar.maximal_associated_points(pushforward(f)(I_sl))
  I = small_generating_set(pop!(decomp))
  current_blow_up = blow_up(I)
  phi = initialize_embedded_blow_up_sequence(current_blow_up,f)
  decomp = [strict_transform(current_blow_up,J) for J in decomp]

  I_sl_temp = I_sl
  while !is_one(I_sl_temp)
    while length(I_sl_temp) > 0
      I = small_generating_set(pop!(decomp))
      phi = _do_blow_up_embedded(phi,I)
      if length(decomp)>0
        decomp = [strict_transform(last_map(phi),J) for J in decomp]
      end
    end
    last_emb = embeddings(phi)[end]
    I_sl_temp = Oscar.ideal_sheaf_of_singular_locus(image_ideal(last_emb))
    decomp = Oscar.maximal_associated_points(I_sl_temp)
  end

## note: normal crossing test currently not implemented
# phi = _ensure_ncr(phi)  
  phi.resolves_sing = true
  return(phi)
end

function _do_blow_up(f::AbsDesingMor, cent::IdealSheaf)
  old_sequence = maps(f)
  X = domain(old_sequence[end])
  X === scheme(cent) || error("center needs to be defined on same scheme")
  current_blow_up = blow_up(cent,var_name=string("v", length(old_sequence), "_"))
  add_map!(f, current_blow_up)
  return(f)
end

function _do_blow_up_embedded(phi,I)
  old_sequence = maps(f)
  X = domain(old_sequence[end])
  X === scheme(cent) || error("center needs to be defined on same scheme")
  current_blow_up = blow_up(cent,var_name=string("v", length(old_sequence), "_"))
  add_map_embedded!(f, current_blow_up)
  return(f)
end


###################################################################################################
# Should go to IdealSheaf.jl, when PR is ready to merge
###################################################################################################

function unit_ideal_sheaf(X::AbsCoveredScheme)
  dd = IdDict{AbsAffineScheme, Ideal}(U=>ideal(OO(U), [one(OO(U))]) for U in affine_patches(X))
  return IdealSheaf(X, dd, check=false)
end

function zero_ideal_sheaf(X::AbsCoveredScheme)
  dd = IdDict{AbsAffineScheme, Ideal}(U=>ideal(OO(U), elem_type(OO(U))[]) for U in affine_patches(X))
  return IdealSheaf(X, dd, check=false)
end

function identity_blow_up(X::AbsCoveredScheme)
  f = BlowupMorphism(X, unit_ideal_sheaf(X))
  return f
end

########################################################################
# Refinements to find local systems of parameters
########################################################################

function find_refinement_with_local_system_of_params(W::AbsAffineScheme; check::Bool=true)
  @check is_smooth(W) "scheme must be smooth"
  @check is_equidimensional(W) "scheme must be equidimensional"
  mod_gens = lifted_numerator.(gens(modulus(OO(W))))::Vector{<:MPolyRingElem}
  M = jacobi_matrix(mod_gens)
  R = ambient_coordinate_ring(W)
  @assert base_ring(M) === R

  n = nrows(M) # the number of variables in the ambient_ring
  r = ncols(M) # the number of generators

  Rn = FreeMod(R, n)
  Rr = FreeMod(R, r)
  phi = hom(Rn, Rr, M)
  codim = n - dim(W)
  phi_cod = induced_map_on_exterior_power(phi, codim)
  M_ext = matrix(phi_cod)
  n_cod = nrows(M_ext)
  r_cod = ncols(M_ext)

  all_entries = Vector{Int}[[i, j] for i in 1:n_cod for j in 1:r_cod]
  M_ext_vec = elem_type(R)[M[i, j] for i in 1:n_cod for j in 1:r_cod]
  min_id = ideal(OO(W), M_ext_vec)
  lambda_vec = coordinates(one(OO(W)), min_id)
  lambda = elem_type(OO(W))[lambda_vec[(i-1)*r_cod + j] for i in 1:n_cod, j in 1:r_cod]
  
  nonzero_indices_linear = [k for k in 1:length(lambda_vec) if !is_zero(lambda_vec[k])]
  non_zero_indices = [[i, j] for i in 1:n_cod, j in 1:r_cod if !is_zero(lambda_vec[(i-1)*r_cod + j])]

  ref_patches = AbsAffineScheme[]
  minor_dict = IdDict{AbsAffineScheme, Tuple{Vector{Int}, Vector{Int}, elem_type(R)}}()
  for (i, j) in non_zero_indices
    h_ij = M_ext[i, j]
    U_ij = hypersurface_complement(W, h_ij)
    I = ordered_multi_index(i, codim, n)
    J = ordered_multi_index(j, codim, r)
    push!(ref_patches, U_ij)
    minor_dict[U_ij] = (indices(I), indices(J), M_ext[i, j])
  end
  res_cov = Covering(ref_patches)
  inherit_glueings!(res_cov, Covering(W))
  return res_cov, minor_dict
 #=
  all_entries = Vector{Int}[[i, j] for i in 1:n for j in 1:r]
  M_vec = elem_type(R)[M[i, j] for i in 1:n for j in 1:r]

  J = ideal(OO(W), M_vec)
  lambda_vec = coordinates(one(OO(W)), J)
  lambda = elem_type(OO(W))[lambda_vec[(i-1)*r + j] for i in 1:n, j in 1:r]

  nonzero_indices_linear = [k for k in 1:length(lambda_vec) if !is_zero(lambda_vec[k])]
  non_zero_indices = [[i, j] for i in 1:n, j in 1:r if !is_zero(lambda_vec[(i-1)*r + j])]

  for (i, j) in non_zero_indices
    h_ij = M[i, j]
    U_ij = hypersurface_complement(W, h_ij)
  end
  =#
end

function find_refinement_with_local_system_of_params_rec(
    W::AbsAffineScheme, 
    mod_gens::Vector{PolyType} = lifted_numerator.(gens(modulus(OO(W)))),
    row_ind::Vector{Int} = Int[],
    col_ind::Vector{Int} = Int[],
    trans_mat::MatrixElem{RingElemType} = change_base_ring(OO(W), jacobi_matrix(mod_gens));
    check::Bool=true
  ) where {PolyType <: MPolyRingElem, RingElemType <: RingElem}
  @show row_ind
  @show col_ind
  show(stdout, "text/plain", trans_mat)
  println()

  # End of recursion
  n = dim(ambient_coordinate_ring(W))
  if length(row_ind) == n - dim(W)
    return [(W, row_ind, col_ind, prod(trans_mat[row_ind[k], col_ind[k]] for k in 1:dim(W); init=one(OO(W))))]
  end

  # generate the unit ideal of OO(W) with the entries of trans_mat
  n = nrows(trans_mat)
  r = ncols(trans_mat)
  all_entries_ind = [[i, j] for i in 1:n if !(i in row_ind) for j in 1:r if !(j in col_ind)]
  all_entries = elem_type(OO(W))[trans_mat[i, j] for (i, j) in all_entries_ind]
  entry_id = ideal(OO(W), all_entries)
  lambda = coordinates(one(OO(W)), entry_id)

  non_zero_entries = [k for k in 1:length(lambda) if !is_zero(lambda[k])]

  loc_results = Tuple{<:AbsAffineScheme, Vector{Int}, Vector{Int}, <:RingElem}[]
  for k in non_zero_entries
    i, j = all_entries_ind[k]
    h_ij = trans_mat[i, j]
    U_ij = hypersurface_complement(W, h_ij)
    res_mat = change_base_ring(OO(U_ij), trans_mat) # TODO: Avoid checks here
    new_row_ind = vcat(row_ind, [i])
    new_col_ind = vcat(col_ind, [j])
    
    # Do Gaussian elimination on the matrix to kill off the other entries in this row
    u = res_mat[i, j]
    inv_u = inv(u)
    for l in 1:r
      l in new_col_ind && continue
      res_mat = add_column!(res_mat, -inv_u * res_mat[i, l], j, l)
    end
    loc_results = vcat(loc_results, 
          find_refinement_with_local_system_of_params_rec(
              U_ij, mod_gens, new_row_ind, new_col_ind, res_mat; check=check
             )
         )
  end
  return loc_results
end


########################################################################
# test for snc                                                         #
########################################################################

function is_snc(divs::Vector{<:EffectiveCartierDivisor})
  is_empty(divs) && error("list of divisors must not be empty")
  X = scheme(first(divs))
  @assert all(d->scheme(d) === X, divs)
  @assert is_smooth(X)
  r = length(divs)
  triv_cov = trivializing_covering.(divs)

  com_ref, incs = common_refinement(triv_cov, default_covering(X))

  for U in patches(com_ref)
    loc_eqns = elem_type(OO(U))[]
    for k in 1:length(incs)
      I = ideal_sheaf(divs[k])
      inc = incs[k]
      V = codomain(inc)
      h = first(gens(I(V)))
      hh = pullback(inc, h)
      push!(loc_eqns, hh)
    end
    is_regular_sequence(loc_eqns) || return false
  end
  return true
end

function common_refinement(list::Vector{<:Covering}, def_cov::Covering)
  isempty(list) && error("list of coverings must not be empty")

  if length(list) == 1
    result = first(list)
    return result, [identity_map(result)]
  end
  patch_list = AbsAffineScheme[]
  anc_list = AbsAffineScheme[]
  to_U_dict = IdDict{AbsAffineScheme, AbsAffineSchemeMor}()
  to_V_dict = IdDict{AbsAffineScheme, AbsAffineSchemeMor}()

  if length(list) == 2
    for U in patches(list[1])
      match_found = false
      for V in patches(list[2])
        success, W = _have_common_ancestor(U, V)
        !success && continue
        match_found = true
        push!(anc_list, W)
        #inc_U = _flatten_open_subscheme(U, W)
        #inc_V = _flatten_open_subscheme(V, W)
        inc_U, h_U = _find_chart(U, W)
        inc_U = PrincipalOpenEmbedding(inc_U, h_U; check=false)
        inc_V, h_V = _find_chart(V, W)
        inc_V = PrincipalOpenEmbedding(inc_V, h_V; check=false)

        UV, to_U, to_V = fiber_product(inc_U, inc_V) 
        push!(patch_list, UV)
        to_U_dict[UV] = to_U
        to_V_dict[UV] = to_V
      end
      !match_found && error("no common ancestor found for $U and $V")
    end
    #anc_cov = Covering(anc_list)
    #inherit_glueings!(anc_cov, def_cov)
    result = Covering(patch_list)
    inherit_glueings!(result, def_cov)

    tot_inc1 = CoveringMorphism(result, list[1], to_U_dict; check=false)
    tot_inc2 = CoveringMorphism(result, list[2], to_V_dict; check=false)
    return result, [tot_inc1, tot_inc2]
  end

  # More than two entries
  n = length(list)
  k = div(n, 2)
  res1, inc1 = common_refinement(list[1:k], def_cov)
  res2, inc2 = common_refinement(list[k+1:end], def_cov) 

  result, inc_tot = common_refinement([res1, res2], def_cov)
  return result, vcat([compose(inc_tot[1], inc1[k]) for k in 1:length(inc1)], 
                      [compose(inc_tot[2], inc2[k]) for k in 1:length(inc2)]
                     )
end


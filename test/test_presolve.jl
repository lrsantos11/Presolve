# OUTDATED...

using MathProgBase
using GLPKMathProgInterface
using Presolve

function make_lp(m::Int, n::Int, s::Float64)
    #m = rand((1:100))
    #n = rand((1:100))
    #m = 1000
    #n = 1000
    #enron data set contained 36,692 nodes and 183,831 nodes at sparsity of 0.00013
    #m = 36692
    #n = 36692
    c = ones(n)
    x = rand((1:1000),n)
    A = sprand(m,n,s)
    b = A*x
    rowlb = b
    rowub = b
    collb = float(copy(x))
    #ub = 1000000*ones(n)
    #lb = fill(-Inf,n)
    colub = fill(Inf,n)
    #return m,n,c,A,b,lb,ub,x
    return m,n,A,collb,colub,c,rowlb,rowub,x
end

function make_lp(m::Int, n::Int, s::Float64, nice::Bool)
    if(!nice)
        return make_lp(m,n,s)
    end
    c = ones(n)
    x = rand((1:10),n)
    a = randn(m,n)
    for i in 1:m
       for j in 1:n
           if(a[i,j] > 0.5)
               a[i,j] = float(rand((1:10)))
           else
               a[i,j] = 0.
           end
       end
     end
    A = sparse(a)
    b = A*x
    #lb = fill(-Inf,n)
    colub = fill(Inf,n)

    collb = float(copy(x))
    rowlb = b
    rowub = b
    #    ub = 10.0*ones(n)
    #return m,n,c,A,b,lb,ub,x
    return m,n,A,collb,colub,c,rowlb,rowub,x
end

# this is only needed because of the way I have generated sample LP instances. Not significant time cost anyway
function trim(x::Array{Float64,1}, y::Array{Float64,1})
    for i in 1:length(x)
        if(x[i] < y[i])
            x[i] = y[i]
        end
    end
    return x
end

#simplest test, fetch one nice instance and compare.
function correctness_test(in1::Int, in2::Int, in3::Float64, in4::Bool)
    i=1
    j=1
    tol = 1e-3

    while(i<= 5)
        @show i,j
        println("---------STARTING ITERATION $i---------")
        m,n,A,collb,colub,c,rowlb,rowub,x = make_lp(in1,in2,in3,true)
        tolerance = tol * ones(n)
        in4 && @show x
        in4 && @show full(A)
        in4 && @show collb
        in4 && @show colub
        in4 && @show c
        in4 && @show rowlb
        in4 && @show rowub

        # p = Presolve_Problem(true,m,n)

        newA,newcollb,newcolub,newc,newrowlb,newrowub,independentvar,active_constr,pstack = presolver!(false,A,collb,colub,c,rowlb,rowub)

        println("AFTER PRESOLVER CALL -------------")
        in4 && @show size(newA), typeof(newA)
        in4 && @show full(newA)
        in4 && @show size(newcollb),size(newcolub)
        in4 && @show newcollb
        in4 && @show newcolub
        in4 && @show size(newc)
        in4 && @show newc
        in4 && @show size(newrowlb),size(newrowub)
        in4 && @show newrowlb
        in4 && @show newrowub
        in4 && @show size(x), typeof(x)
        in4 && @show independentvar
        ans = Array{Float64,1}()
        #ans = fill(0.0,length(x))
        if(length(find(independentvar))!=0)
            #presol = linprog(newc, newA, '=', newb,newlb,newub, GLPKSolverLP(presolve=false))
            presol = linprog(newc, newA, newrowlb, newrowub, newcollb,newcolub)
            #presol = linprog(newc, newA, '=', newb, -Inf, Inf)
            in4 && println(newc)
            in4 && println(newA)
            in4 && println(newrowlb)
            in4 && println(newrowub)
            in4 && println(newcollb)
            in4 && println(newcolub)

            in4 && @show ans = presol.sol
            in4 && @show independentvar
            if(presol.status!= :Optimal)
                println("$(presol.status)")
                i += 1
                break
            end
            presol.status != :Optimal && error("ERROR - Input feasible problem with an optimal solution but after presolving solver status is not optimal")
            #ans = presol.sol
        end
        #@show pstack
        finalsol = return_postsolved(ans,independentvar,active_constr,pstack)
        #@show finalsol
        finalsol = trim(finalsol,collb)

        in4 && @show x
        in4 && @show finalsol

        if( ((x - finalsol) .< tolerance) == trues(n) )
            println("PASS!")
            j+=1
        else
            @show x - finalsol
            @show A*x
            @show A*finalsol
            if(is_equal(A*x,A*finalsol))
                println("PASS!")
                j+=1
            else
                error("DIDNT PASS!!!")
            end
        end
        i+=1
    end
    if(i == j)
        @show i,j
        println("------Presolve works subject to randomized testing-----")
    end
end

function time_test(in1::Int, in2::Int, in3::Float64, in4::Bool)
    tol = 1e-3
    println("---------STARTING TIME PROFILE TEST--------")
    m,n,c,A,b,lb,ub,x = make_lp(in1,in2,in3,in4)
    @show m,n

    tolerance = tol * ones(n)
    println("GLPK Presolve")
    @time begin
        answer = linprog(c,A,'=',b,lb,ub,GLPKSolverLP(presolve=true))
        answer.status != :Optimal && error("Input feasible problem with an optimal solution but solver status is not optimal")
    end
println("My Presolve")

@time begin
        newc,newA,newb,newlb,newub,independentvar,pstack = presolver!(in4,c,A,b,lb,ub)
        ans = Array{Float64,1}()
    #    @show size(newA)
        #(newA == A) && error("No Presolving Done")
            if(length(find(independentvar))!=0)
            presol = linprog(newc, newA, '=', newb,newlb,newub, GLPKSolverLP(presolve=false))
            #presol = linprog(newc, newA, '=', newb,newlb,newub)
            presol.status != :Optimal && error("Input feasible problem with an optimal solution but after presolving solver status is not optimal")
            ans = presol.sol
            end
        finalsol = return_postsolved(ans,independentvar,pstack)
        finalsol = trim(finalsol,lb)
    end
    @show size(newA)

    #@show answer.sol
    #@show finalsol
end

function noob_test()
    m = 4
    n = 4
    A = sprand(m,n,0.5)
    for i in 1:4
       for j in 1:4
           if(A[i,j] > 0.5)
               A[i,j] = float(rand((1:10)))
           else
               A[i,j] = 0.
           end
       end
   end
   @show full(A)
   lb = fill(-Inf,4)
   ub = fill(Inf,4)
   x = [1,2,3,4]
   b = A*x
   @show b
   c = [1.0,1,1,1]
   newc,newA,newb,newlb,newub,independentvar,pstack = presolver!(true,c,A,b,lb,ub)
   @show size(newA)
   #(newA == A) && error("No Presolving Done")
   ans = Array{Float64,1}()
       if(length(find(independentvar))!=0)
       presol = linprog(newc, newA, '=', newb,newlb,newub, GLPKSolverLP(presolve=false))
       #presol = linprog(newc, newA, '=', newb,newlb,newub)
       presol.status != :Optimal && error("Input feasible problem with an optimal solution but after presolving solver status is not optimal")
       ans = presol.sol
       end
   finalsol = return_postsolved(ans,independentvar,pstack)
   finalsol = trim(finalsol,float(x))
#end
#@show answer.sol
@show finalsol
@show x
end

function do_tests(correctness::Bool, time::Bool)
    if(correctness)
        #correctness_tests
        correctness_test(5,5,0.3,false)
    end

    if(time)
        # Time-Profile tests
        #time_test(10,10,0.5,false)
        #println("AGAIN")
        #time_test(100,100,0.01,false)
        #println("AGAIN")
        time_test(1000,1000,0.001,false)
        #println("AGAIN")
        #time_test(10000,10000,0.0001,false)
        #println("AGAIN")
        #time_test(100000,100000,0.00001,false)
    end
end

`
function checkapi(in1::Int, in2::Int, in3::Float64, in4::Bool)
    tol = 1e-3
    println("-------Testing the API--------")
    m,n,c,A,b,lb,ub,x = make_lp(in1,in2,in3,in4)
    @show m,n

    tolerance = tol * ones(n)
    println("GLPK Presolve")
    @time begin
        answer = linprog(c,A,'=',b,lb,ub,GLPKSolverLP(presolve=true))
        answer.status != :Optimal && error("Input feasible problem with an optimal solution but solver status is not optimal")
    end
println("My Presolve")

@time begin
        answer = linprog(c,A,'=',b,lb,ub,GLPKSolverLP(presolve=false),presolve=true)
        answer.status != :Optimal && error("Input feasible problem with an optimal solution but solver status is not optimal")
    end
    @show size(newA)

end`

println("-------------------RANDOMIZED CORRECTNESS TESTS-----------------")
do_tests(true,false)
#noob_test()

#time_test(1,1,0.3,false)
#Profile.clear()

#println("-------------------RANDOMIZED TIME TESTS---------------------")
#do_tests(false,true)
#@profile do_tests(false,true)

#Profile.print(format=:flat)
`using ProfileView
ProfileView.view()
ProfileView.svgwrite("profile_results2.svg")`


#checkapi(10,10,0.5,false)

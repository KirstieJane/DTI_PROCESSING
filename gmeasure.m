%Used in GrowMeasures
%calculate measures
        %%%%%%%%%%% Degrees
        deg=degrees_und(A);
        degr=degrees_und(R);
        s.kmean(x,g)=mean(deg);
        s.k(x,g,1:size(A))=(deg);
        
        %%%%%%%%%%%% Assortativity
        s.a(x,g)=assortativity_bin(A,0); %weights are discarded even if they exist
        s.arand(x,g)=assortativity_bin(R,0);
        
        %%%%%%%%%%%% Modularity
        [Com s.M(x,g)]=modularity_louvain_und(A);
        %[Comr s.Mrand(x,g)]=modularity_louvain_und(R);
        
        
        %%%%%%%%%%%% Clustering
        s.C(x,g)=mean(clustering_coef_bu(A));
        s.Crand(x,g)=mean(clustering_coef_bu(R));
      
        %%%%%%%%%%%% Distance matrix
        Dist=distance_bin(A);
        DistRand=distance_bin(R);
        %%%%%%%%%%%% Path Length
        s.L(x,g)=mean(mean(Dist))*n/(n-1);
        s.Lrand(x,g)=mean(mean(DistRand))*n/(n-1);
        
        %%%%%%%%%%%%% Small-World Coefficient
        s.Sigma(x,g)=(s.C(x,g)./s.Crand(x,g))./(s.L(x,g)./s.Lrand(x,g));
        
        %%%%%%%%%%%%% Efficiency        
        s.E(x,g)=efficiency_bin(A);
        s.Erand(x,g)=efficiency_bin(R);
        
        %%%%%%%%%%%% Cost-Efficiency
        s.CE(x,g)=s.E(x,g)-s.cost(g);
        s.CErand(x,g)=s.Erand(x,g)-s.cost(g);
        %%%%%%%%%%%%

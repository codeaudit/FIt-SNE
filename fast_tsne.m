function [mappedX, costs, initialError] = fast_tsne(X,  opts)
%FAST_TSNE Runs the C++ implementation of FMM t-SNE
%
%   mappedX = fast_tsne(X, opts, initial_data)
%            X - Input dataset, rows are observations and columns are
%            variables
%            opts - a struct with the following possible parameters 
%                   opts.no_dims - dimensionality of the embedding
%                        Default 2.
%                   opts.perplexity - perplexity is used to determine the
%                       bandwidth of the Gaussian kernel in the input
%                       space.  Default 30.
%                   opts.theta - Set to 0 for exact.  If non-zero, then will use either
%                       Barnes Hut or FIt-SNE based on opts.nbody_algo.  If Barnes Hut, then
%                       this determins the accuracy of BH approximation.
%                       Default 0.5.
%                   opts.max_iter - Number of iterations of t-SNE to run.
%                       Default 1000.
%                   opts.nbody_algo - if theta is nonzero, this determins whether to
%                        use FIt-SNE or Barnes Hut approximation. Default is FIt-SNE.
%                        set to be 'bh' for Barnes Hut
%                   opts.early_exag_coeff - coefficient for early exaggeration
%                       (>1). Default 12.
%                   opts.stop_lying_iter - When to switch off early exaggeration.
%                       Default 200.
%                   opts.start_late_exag_iter - When to start late
%                       exaggeration. set to -1 to not use late exaggeration
%                       Default -1.
%                   opts.late_exag_coeff - Late exaggeration coefficient.
%                      Set to -1 to not use late exaggeration.
%                       Default -1
%                   opts.no_momentum_during_exag - Set to 0 to use momentum
%                       and other optimization tricks. 1 to do plain,vanilla
%                       gradient descent (useful for testing large exaggeration
%                       coefficients)

% Runs the C++ implementation of fast t-SNE using either the IFt-SNE
% implementation or Barnes Hut


% Copyright (c) 2014, Laurens van der Maaten (Delft University of Technology)
% All rights reserved.
% 
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are met:
% 1. Redistributions of source code must retain the above copyright
%    notice, this list of conditions and the following disclaimer.
% 2. Redistributions in binary form must reproduce the above copyright
%    notice, this list of conditions and the following disclaimer in the
%    documentation and/or other materials provided with the distribution.
% 3. All advertising materials mentioning features or use of this software
%    must display the following acknowledgement:
%    This product includes software developed by the Delft University of Technology.
% 4. Neither the name of the Delft University of Technology nor the names of 
%    its contributors may be used to endorse or promote products derived from 
%    this software without specific prior written permission.
%
% THIS SOFTWARE IS PROVIDED BY LAURENS VAN DER MAATEN ''AS IS'' AND ANY EXPRESS
% OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES 
% OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO 
% EVENT SHALL LAURENS VAN DER MAATEN BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
% SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, 
% PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR 
% BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING 
% IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY 
% OF SUCH DAMAGE.
    if (nargin == 1)
        opts.perplexity = 30;
    end
    if (~isfield(opts, 'perplexity'))
        perplexity = 30;
    else
        perplexity = opts.perplexity;
    end
    if (~isfield(opts, 'no_dims'))
        no_dims = 2;
    else
        no_dims = opts.no_dims;
    end

    if (~isfield(opts, 'theta'))
        theta = 0.5;
    else
        theta = opts.theta;
    end
    
    if (~isfield(opts, 'use_existing_P'))
        delete temp/*.dat
    end
    if (~isfield(opts, 'stop_lying_iter'))
        stop_lying_iter = 200;
    else
        stop_lying_iter = opts.stop_lying_iter;
    end
    
    if (~isfield(opts, 'max_iter'))
        max_iter = 1E3;
    else
        max_iter = opts.max_iter;
    end
    
    if (~isfield(opts, 'early_exag_coeff'))
        early_exag_coeff = 12;
    else
        early_exag_coeff = opts.early_exag_coeff;
    end
    if (~isfield(opts, 'start_late_exag_iter'))
        start_late_exag_iter = -1;
    else
        start_late_exag_iter = opts.start_late_exag_iter;
    end
    
    if (~isfield(opts, 'late_exag_coeff'))
        late_exag_coeff = -1;
    else
        late_exag_coeff = opts.late_exag_coeff;
    end
    
    if (~isfield(opts, 'rand_seed'))
        rand_seed = -1;
    else
        rand_seed = opts.rand_seed;
    end
    
    if (~isfield(opts, 'nbody_algo'))
        nbody_algo = 2; %default is fmm
    else
        if ( opts.nbody_algo == 'bh')
            nbody_algo = 1;
        else
            nbody_algo = 2;
        end
    end
    if (~isfield(opts, 'knn_algo'))
        knn_algo = 1; %default is ann
    else
        if ( opts.knn_algo == 'vptree')
            knn_algo = 2;
        else
            knn_algo = 1;
        end
    end
    
    

    if (~isfield(opts, 'no_momentum_during_exag'))
        no_momentum_during_exag = 0;
    else
        no_momentum_during_exag = opts.no_momentum_during_exag;
    end
    if (~isfield(opts, 'n_trees'))
        n_trees = 50;
    else
        n_trees = opts.n_trees;
    end
    if (~isfield(opts, 'search_k'))
        search_k = 3*perplexity*n_trees;
    else
        search_k = opts.search_k;
    end

    K = -1;
    sigma = -30;

    
    X = double(X);
    
    tsne_path = 'bin';
    
    % Compile t-SNE C code
    if(~exist(fullfile(tsne_path,'./fast_tsne'),'file') && isunix)
        system(sprintf('g++ -std=c++11 -O3  src/sptree.cpp src/tsne.cpp src/nbodyfft.cpp  -o bin/fast_tsne -pthread -lfftw3 -lm'));
    end

    % Run the fast diffusion SNE implementation
    write_data('temp/data.dat',X, no_dims, theta, perplexity, max_iter, stop_lying_iter, K, sigma, nbody_algo,no_momentum_during_exag, knn_algo, early_exag_coeff,n_trees, search_k,start_late_exag_iter, late_exag_coeff,rand_seed);

    disp('Data written');
    tic
    [flag, cmdout] = system(fullfile(tsne_path,'/fast_tsne'), '-echo')
    if(flag~=0)
        error(cmdout);
    end
    toc
    [mappedX, landmarks, costs, initialError] = read_data(max_iter);   
    delete('temp/data.dat');
    delete('temp/result.dat');
end


% Writes the datafile for the fast t-SNE implementation
function write_data(filename, X, no_dims, theta, perplexity, max_iter, stop_lying_iter,K, sigma, nbody_algo,no_momentum_during_exag, knn_algo, early_exag_coeff,n_trees, search_k,start_late_exag_iter, late_exag_coeff,rand_seed)
    [n, d] = size(X);
    %h = fopen('data.dat', 'wb');
    h = fopen(filename, 'wb');
	fwrite(h, n, 'integer*4');
	fwrite(h, d, 'integer*4');
    fwrite(h, theta, 'double');
    fwrite(h, perplexity, 'double');
	fwrite(h, no_dims, 'integer*4');
    fwrite(h, max_iter, 'integer*4');
        fwrite(h, stop_lying_iter, 'integer*4');
    fwrite(h, K, 'int');
    fwrite(h, sigma, 'double');
    fwrite(h, nbody_algo, 'int');
    fwrite(h, knn_algo, 'int');
    fwrite(h, early_exag_coeff, 'double');
    fwrite(h, no_momentum_during_exag, 'int');
    fwrite(h, n_trees, 'int');
    fwrite(h, search_k, 'int');
        fwrite(h, start_late_exag_iter, 'int');
        fwrite(h, late_exag_coeff, 'double');

    
    fwrite(h, X', 'double');
        fwrite(h, rand_seed, 'integer*4');

	fclose(h);
end


% Reads the result file from the fast t-SNE implementation
function [X, landmarks, costs, initialError] = read_data(max_iter)
    h = fopen('temp/result.dat', 'rb');
    initialError = fread(h, 1, 'double');
	n = fread(h, 1, 'integer*4');
	d = fread(h, 1, 'integer*4');
	X = fread(h, n * d, 'double');
    landmarks = fread(h, n, 'integer*4');
    costs = fread(h, max_iter, 'double');      % this vector contains only zeros
    
    X = reshape(X, [d n])';
	fclose(h);
end

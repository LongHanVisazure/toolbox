function [Vx,Vy,reliab]=optFlowLk( I1, I2, smooth, radius, show )
% Calculate optical flow using Lucas & Kanade (fast, parallel code).
%
% USAGE
%  [Vx,Vy,reliab] = optFlowLk( I1,I2, smooth, radius, [show] )
%
% INPUTS
%  I1, I2   - input images to calculate flow between
%  smooth   - smoothing radius for triangle filter (may be 0)
%  radius   - integration radius for weighted window
%  show     - [0] figure to use for display (no display if == 0)
%
% OUTPUTS
%  Vx, Vy   - x,y components of flow  [Vx>0->right, Vy>0->down]
%  reliab   - reliability of flow in given window (cornerness of window)
%
% EXAMPLE
%  % create square + translated square (B) + rotated square (C)
%  A=zeros(50,50); A(16:35,16:35)=1;
%  B=zeros(50,50); B(17:36,17:36)=1;
%  C=imrotate(A,5,'bil','crop'); smooth=3; radius=6;
%  optFlowLk( A, B, smooth, radius, 3e-6, 1 );
%  optFlowLk( A, C, smooth, radius, 3e-6, 2 );
%  % compare on stored real images (of mice)
%  load optFlowData; show=1; smooth=2; radius=8; alpha=2;
%  [Vx,Vy,reliab] = optFlowLk( I5A, I5B, smooth, radius, show );
%  [Vx,Vy] = optFlowHorn( I5A, I5B, smooth, alpha, 500, show+1 );
%
% See also optFlowHorn, convTri, imtransform2
%
% Piotr's Image&Video Toolbox      Version NEW
% Copyright 2012 Piotr Dollar.  [pdollar-at-caltech.edu]
% Please email me if you find bugs, or have suggestions or questions!
% Licensed under the Simplified BSD License [see external/bsd.txt]

% get default parameters and do error checking
if( nargin<5 || isempty(show)); show=0; end
if( ndims(I1)~=2 || ndims(I2)~=2 || any(size(I1)~=size(I2)) )
  error('Input images must be 2D and have same dimensions.'); end

% run optical flow in coarse to fine fashion
if(~isa(I1,'single')), I1=single(I1); I2=single(I2); end
[h,w]=size(I1); nScales=floor(log2(min(h,w)))-2;
for s=1:nScales
  % get current scale and I1s and I2s at given scale
  scale=2^(nScales-s); h1=round(h/scale); w1=round(w/scale);
  if( scale==1 ), I1s=I1; I2s=I2; else
    I1s=imResample(I1,[h1 w1]); I2s=imResample(I2,[h1 w1]); end
  % initialize Vx,Vy or upsample from previous scale
  if(s==1), Vx=zeros(h1,w1,'single'); Vy=Vx; else
    Vx=imResample(Vx,[h1 w1])*2; Vy=imResample(Vy,[h1 w1])*2; end
  % transform I1s according to current estimate of Vx and Vy
  if(s), I1s=imtransform2(I1s,[],'pad','replciate','vs',-Vx,'us',-Vy); end
  % run optical flow on current scale
  [Vx1,Vy1,reliab]=optFlowLk1(I1s,I2s,smooth,radius);
  Vx=Vx+Vx1; Vy=Vy+Vy1;
end

% show quiver plot on top of I1
if(show), figure(show); clf; im(I1); hold('on');
  quiver(Vx,Vy,0,'-b'); hold('off'); end

end

function [Vx,Vy,reliab] = optFlowLk1( I1, I2, smooth, radius  )
% http://en.wikipedia.org/wiki/Lucas-Kanade_method
I1=convTri(I1,smooth); I2=convTri(I2,smooth);
% Compute elements of A'A and also of A'b
radius=min(radius,floor(min(size(I1,1),size(I1,2))/2)-1);
[Ix,Iy]=gradient2(I1); It=I2-I1; AAxy=convTri(Ix.*Iy,radius);
AAxx=convTri(Ix.^2,radius); ABxt=convTri(-Ix.*It,radius);
AAyy=convTri(Iy.^2,radius); AByt=convTri(-Iy.*It,radius);
% Find determinant and trace of A'A
AAdet=AAxx.*AAyy-AAxy.^2; AAdeti=1./(AAdet+eps); AAtr=AAxx+AAyy;
% Compute components of velocity vectors (A'A)^-1 * A'b
Vx = AAdeti .* ( AAyy.*ABxt - AAxy.*AByt);
Vy = AAdeti .* (-AAxy.*ABxt + AAxx.*AByt);
% Check for ill conditioned second moment matrices
reliab = 0.5*AAtr - 0.5*sqrt(AAtr.^2-4*AAdet);
end

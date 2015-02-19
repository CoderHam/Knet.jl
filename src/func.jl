using CUDArt

noop(l,x)=x
softforw(l,y)=y
function reluforw(l,y::CudaArray)  ccall((:reluforw,libkunet),Void,(Cint,Cmat),length(y),y); y end
function reluback(l,dy::CudaArray) ccall((:reluback,libkunet),Void,(Cint,Cmat,Cmat),length(dy),l.y,dy); dy end
function softback(l,dy::CudaArray) ccall((:softback,libkunet),Void,(Cint,Cint,Cmat,Cmat),size(dy,1),size(dy,2),l.y,dy); dy end
drop(x::CudaArray, xmask::CudaArray, dropout, scale)=ccall((:drop,libkunet),Void,(Cint,Cmat,Cmat,Cfloat,Cfloat),length(x),x,xmask,dropout,scale)

function dropforw(l, x)
    resize(l, :xmask, x)
    rand!(l.xmask)
    drop(x, l.xmask, l.dropout, 1/(1-l.dropout))
    return x
end

function dropback(l, dx)
    drop(dx, l.xmask, l.dropout, 1/(1-l.dropout))
    return dx
end

function drop(x, xmask, dropout, scale)
    for i=1:length(x)
        x[i] = (xmask[i] < dropout ? zero(x[i]) : scale * x[i])
    end
end

function reluforw(l,y)
    for i=1:length(y)
        if (y[i] < 0)
            y[i] = 0
        end
    end
    return y
end

function reluback(l, dy)
    for i=1:length(dy)
        if (l.y[i] <= 0)
            dy[i] = 0
        end
    end
    return dy
end

function softback(l, dy)
    # we do softmax here instead of in forw
    # overwriting y from unnormalized log probabilities to normalized probabilities
    # NumericExtensions.softmax!(y,y,1) allocates unnecessary memory
    # dy is a 0-1 matrix of correct answers
    # will overwrite it with the gradient
    # TODO: is this a good interface?
    # TODO: other types of final layers, losses?

    y = l.y
    for j=1:size(y,2)
        ymax = y[1,j]
        for i=2:size(y,1)
            if (y[i,j] > ymax)
                ymax = y[i,j]
            end
        end
        ysum = zero(ymax)
        for i=1:size(y,1)
            y[i,j] = exp(y[i,j] - ymax)
            ysum += y[i,j]
        end
        for i=1:size(y,1)
            y[i,j] /= ysum
            dy[i,j] = (y[i,j] - dy[i,j]) / size(y,2)
        end
    end
    return dy
end



function pred = cosineClassifier(X,y_prot_O,y_prot_C)

pred=zeros(size(X,1),1);

cosine_O = (X*y_prot_O)/ (norm(X)*norm(y_prot_O));
cosine_C = (X*y_prot_C)/ (norm(X)*norm(y_prot_C));

pred=double(cosine_O >= cosine_C);

end
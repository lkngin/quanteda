using namespace Rcpp;
using namespace std;

#ifndef __QUANTEDA__
#define __QUANTEDA__

namespace quanteda{

    inline String join_character_vector(const CharacterVector &tokens, const String &delim){
        if(tokens.size() == 0) return "";
        String token = tokens[0];
        for (int i = 1; i < tokens.size(); i++) {
          token += delim;
          token += tokens[i];
          //Rcout << "Joined " << token.get_cstring()  << "\n";
        }
        token.set_encoding(CE_UTF8);
        return token;
      }
    
    inline std::string join_vector(std::vector< std::string > tokens, std::string delim){
        if(tokens.size() == 0) return "";
        std::string token = tokens[0];
        for (int i = 1; i < tokens.size(); i++) {
          token += delim + tokens[i];
        }
        return token;
    }

    // Tokens object
    class Tokens {
      public:
      Tokens(List documents_, List vocaburary_): documents(documents_), vocaburary(vocaburary_){}
      Rcpp::List documents, vocaburary;;
    };
}

#endif